package;

import haxe.DynamicAccess;
import haxe.Exception;
import haxe.Json;
import sys.io.File;

class GenerateDefinition {
  private static var domains:Map<String, String> = [];
  private static inline var FRAME_OVERHEAD:Int = 8; // type + channel + size + frame-end
  private static inline var METHOD_OVERHEAD:Int = FRAME_OVERHEAD + 4; // F_O + classId + methodId
  private static inline var PROPERTIES_OVERHEAD:Int = FRAME_OVERHEAD + 4 + 8 + 2;// F_O + classId + methodId

  /**
   * Helper to replace dashes with undescores
   * @param s
   * @return String
   */
  static private function ReplaceUnderscore(s:String):String {
    return StringTools.replace(s, '-', '_');
  }

  /**
   * Helper to generate method name
   * @param clazz
   * @param method
   * @return String
   */
  private static function MethodName(clazz:Dynamic, method:Dynamic):String {
    return Initial(clazz.name) + method.name.split('-').map(Initial).join('');
  }

  /**
   * Helper to generate propertyName
   * @param dashed
   * @return String
   */
  private static function PropertyName(dashed:String):String {
    var parts = dashed.split('-');
    return parts[0] + parts.slice(1).map(Initial).join('');
  }

  /**
   * Ucfirst helper
   * @param part
   * @return String
   */
  private static function Initial(part:String):String {
    return part.charAt(0).toUpperCase() + part.substr(1);
  }

  /**
   * Argument to object helper
   * @param a
   * @return Dynamic
   */
  private static function Argument(a:Dynamic):Dynamic {
    var type = Reflect.hasField(a, "type") ? a.type : domains[a.domain];
    var friendlyName = PropertyName(a.name);
    return {type: type, name: friendlyName, def: Reflect.field(a, 'default-value')};
  }

  /**
   * Helper to generate method id build from class id and method id
   * @param clazz
   * @param method
   * @return Int
   */
  private static function MethodId(clazz:Dynamic, method:Dynamic):Int {
    return (clazz.id << 16) + method.id;
  }

  /**
   * Helper to build properties name
   * @param clazz
   * @return String
   */
  private static function PropertiesName(clazz:Dynamic):String {
    return Initial(clazz.name) + 'Properties';
  }

  /**
   * Wrapper to declare fields with default value null
   * @param args
   * @return String
   */
  private static function FieldsDecl(args:Array<Dynamic>):String {
    var decl:String = 'var fields:Dynamic = {';
    for ( arg in args ) {
      decl += arg.name + ": null,";
    }
    decl += "};";
    return decl;
  }

  /**
   * Default value representation
   * @param arg
   * @return String
   */
  private static function DefaultValueRepr(arg:Dynamic):String {
    switch (arg.type) {
    case 'longstr':
      return Json.stringify(arg.def);
    default:
      // assumes no tables as defaults
      return Json.stringify(arg.def);
    }
  }

  /**
   * Emit code to assign the arg value to `val`
   * @param a
   * @return String
   */
  private static function AssignArg(a:Dynamic):String {
    return "
    val = fields." + a.name + ";";
  }

  /**
   * Emit code to assign the arg value to `val` or use default
   * @param a
   * @return String
   */
  private static function AssignOrDefault(a:Dynamic):String {
    return "
    val = fields." + a.name + ";
    if (val == null) val = " + DefaultValueRepr(a) + ";";
  }

  /**
   * Emit code for value type tests
   * @param arg
   * @return String
   */
  private static function ValTypeTest(arg:Dynamic):String {
    switch (arg.type) {
      // everything is booleany
      case 'bit':
        return 'Std.isOfType(val, Bool)';
      case 'octet',
           'short',
           'long',
           'longlong',
           'timestamp':
        return "(Std.isOfType(val, Int) || Std.isOfType(val, Float)) && !Math.isNaN(val)";
      case 'shortstr':
        return "Std.isOfType(val, String) && cast(val, String).length < 256";
      case 'longstr':
        return "Std.isOfType(val, String)";
      case 'table':
        return "Std.isOfType(val, Dynamic)";
      default:
        throw new haxe.Exception("Unknown type");
    }
  }

  /**
   * Type to readable description
   * @param t
   */
  private static function TypeDesc(t) {
    switch (t) {
    case 'bit':
      return 'booleany';
    case 'octet',
         'short',
         'long',
         'longlong',
         'timestamp':
      return 'a number (but not NaN)';
    case 'shortstr':
      return 'a string (up to 255 chars)';
    case 'longstr':
      return 'a String';
    case 'table':
      return 'a Dynamic';
    default:
      throw new haxe.Exception("Unknown type");
    }
  }

  /**
   * Emit code for assigning an argument value to `val`, checking that
   * it exists (if it does not have a default) and is the correct
   * type.
   * @param a
   */
  private static function CheckAssignArg(a) {
    var logic:String = AssignArg(a);
    logic += "
    if (val == null) {";
    if (a.def != null) {
      logic += "
      val = " + DefaultValueRepr(a) + ";";
    }
    else {
      logic += '
      throw new haxe.Exception("Missing value for mandatory field \\"${a.name}\\"");';
    }
    logic += '
    } else if (!(${ValTypeTest(a)})) {
      throw new haxe.Exception("Field \\"${a.name}\\" is the wrong type; must be ${TypeDesc(a.type)}\");
    }';
    return logic;
  }

  private static function CreateTable(a:Dynamic):String {
    return "
    var " + TableVar(a) + ":Bytes = null;";
  }

  /**
   * Emit code for encoding `val` as a table and assign to a fresh
   * variable (based on the arg name).
   * @param a
   * @return String
   */
  private static function AssignTable(a:Dynamic, withCreate:Bool = true):String {
    return "
    // ensure big endian and flush previous content
    SCRATCH.bigEndian = true;
    SCRATCH.flush();
    // encode table" + (withCreate ? "
    var " + TableVar(a) + ":Bytes = Codec.EncodeTable(SCRATCH, val);" : "
    " + TableVar(a) + " = Codec.EncodeTable(SCRATCH, val);");
  }

  /**
   * Emit code for table variable name
   * @param a
   * @return String
   */
  private static function TableVar(a:Dynamic):String {
    return a.name + '_encoded';
  }

  /**
   * Emit code for string length variable
   * @param a
   * @return String
   */
  private static function StringLenVar(a:Dynamic):String {
    return a.name + '_len';
  }

  /**
   * Emit code to assign string length variable
   * @param a
   * @return String
   */
  private static function AssignStringLen(a:Dynamic):String {
    return "
    var " + StringLenVar(a) + ":Int = cast(val, String).length;";
  }

  /**
   * Flag at position
   * @param index
   * @return Int
   */
  private static function FlagAt(index:Int):Int {
    return 1 << (15 - index);
  }

  /**
   * Emit code for decoder function
   * @param m
   * @return String
   */
  private static function DecoderFn(m:Dynamic):String {
    var method:String = "
  public static function " + m.decoder + "(buffer:BytesInput):Dynamic {
    var val:Dynamic;
    var len:Int = 0;
    var b:Bytes;
    var bits:BitsInput = new BitsInput(buffer);
    " + FieldsDecl(m.args) + "
    buffer.bigEndian = true;";

    var bitsInARow:Int = 0;
    for (a in cast(m.args, Array<Dynamic>)) {
      var field = "fields." + a.name;

    // Flush any collected bits before doing a new field
    if (a.type != 'bit' && bitsInARow > 0) {
      method += "
    // read full byte before starting with next";
      for (i in 0...8 - bitsInARow) {
        method += "
    bits.readBit();";
      }
      bitsInARow = 0;
    }

    switch (a.type) {
    case 'octet':
      method += "
    val = buffer.readByte();";
    case 'short':
      method += "
    val = buffer.readInt16();";
    case 'long':
      method += "
    val = buffer.readInt32();";
    case 'longlong',
         'timestamp':
      method += "
    val = buffer.readInt64();";
    case 'bit':
      method += "
    val = bits.readBit();";
      if (bitsInARow == 7) {
        bitsInARow = 0;
      }
      else {
        bitsInARow++;
      }
    case 'longstr':
      method += "
    len = buffer.readInt32();
    val = buffer.readString(len);";
    case 'shortstr':
      method += "
    len = buffer.readInt8();
    val = buffer.readString(len);";
    case 'table':
      method += "
    len = buffer.readInt32();
    b = Bytes.alloc(len);
    buffer.readBytes(b, 0, len);
    val = Codec.DecodeFields(b);";
    default:
      throw new Exception("Unexpected type in argument list: " + a.type);
    }
      method += "
    " + field + " = val;";
    }
    method += "
    return fields;
  }";
    return method;
  }

  /**
   * Emit code for encoder function
   * @param m
   * @return String
   */
  private static function EncoderFn(m:Dynamic):String {
    var args:Array<Dynamic> = m.args;

    var method:String = "
  public static function " + m.encoder + "(channel:Int, fields:Dynamic):Bytes {
    var offset:Int = 0;
    var val:Dynamic = null;
    var bits:Int = 0;
    var varyingSize:Int = 0;
    var len:Int;
    var offset:Int = 0;";

    // Encoding is split into two parts. Some fields have a fixed size
    // (e.g., integers of a specific width), while some have a size that
    // depends on the datum (e.g., strings). Each field will therefore
    // either 1. contribute to the fixed size; or 2. emit code to
    // calculate the size (and possibly the encoded value, in the case
    // of tables).
    var fixedSize:Int = METHOD_OVERHEAD;
    var bitsInARow:Int = 0;
    for (arg in args) {
      if (arg.type != 'bit') {
        bitsInARow = 0;
      }

      switch (arg.type) {
        // varying size
        case 'shortstr':
          method += CheckAssignArg(arg);
          method += AssignStringLen(arg);
          method += "
    varyingSize += " + StringLenVar(arg) + ";";
          fixedSize += 1;
        case 'longstr':
          method += CheckAssignArg(arg);
          method += "
    varyingSize += val.length;";
          fixedSize += 4;
        case 'table':
          // For a table we have to encode the table before we can see its
          // length.
          method += CheckAssignArg(arg);
          method += AssignTable(arg);
          method += "
    varyingSize += " + TableVar(arg) + ".length;";
        // fixed size
        case 'octet': fixedSize += 1;
        case 'short': fixedSize += 2;
        case 'long': fixedSize += 4;
        case 'longlong': //fall through
        case 'timestamp':
          fixedSize += 8;
        case 'bit':
          bitsInARow ++;
          // open a fresh pack o' bits
          if (bitsInARow == 1) fixedSize += 1;
          // just used a pack; reset
          else if (bitsInARow == 8) bitsInARow = 0;
      }
    }

    var bitsInARow:Int = 0;
    method += "
    var output:BytesOutput = new BytesOutput();
    output.bigEndian = true;
    output.prepare("+ fixedSize + " + varyingSize);
    output.writeByte(amqp.helper.protocol.Constant.FRAME_METHOD);
    output.writeInt16(channel);
    output.writeInt32(0); // space for final size at the end
    output.writeInt32(" + m.id + ");
    //output.writeInt16(" + m.clazzId + ");
    //output.writeInt16(" + m.methodId + ");";

    for ( arg in cast(m.args, Array<Dynamic>) ) {
      // Flush any collected bits before doing a new field
      if (arg.type != 'bit' && bitsInARow > 0) {
        method += "
    output.writeByte(bits);";
        bitsInARow = 0;
      }

      switch (arg.type) {
        case 'octet':
          method += CheckAssignArg(arg);
          method += "
    output.writeByte(val);";
        case 'short':
          method += CheckAssignArg(arg);
          method += "
    output.writeInt16(val);";
        case 'long':
          method += CheckAssignArg(arg);
          method += "
    output.writeInt32(val);";
        case 'longlong':
        case 'timestamp':
          method += CheckAssignArg(arg);
          method += "
    output.writeInt64(val);";
        case 'bit':
          method += CheckAssignArg(arg);
          method += "
    if (cast(val, Bool)) {
      bits += " + ( 1 << bitsInARow ) + ";
    }";
          if (bitsInARow == 7) { // I don't think this ever happens, but whatever
            method += "
    output.writeByte(bits);
    bits = 0;";
            bitsInARow = 0;
          }
          else
          {
            bitsInARow++;
          }
        case 'shortstr':
          method += AssignOrDefault(arg);
          method += "
    output.writeByte(" + StringLenVar(arg) + ");
    output.writeString(val, haxe.io.Encoding.UTF8);";
        case 'longstr':
          method += AssignOrDefault(arg);
          method += "
    len = cast(val, String).length;
    output.writeInt32(len);
    output.writeString(val, haxe.io.Encoding.UTF8);";
        case 'table':
          method += "
    output.writeBytes(" + TableVar(arg) + ", 0, " + TableVar(arg) + ".length);";
        default: throw new Exception("Unexpected argument type: " + arg.type);
      }
    }

    // Flush any collected bits at the end
    if (bitsInARow > 0) {
      method += "
    output.writeByte(bits);";
    }

    method += "
    output.writeByte(amqp.helper.protocol.Constant.FRAME_END);
    // hacky push in size
    var sizeOutput:BytesOutput = new BytesOutput();
    sizeOutput.bigEndian = true;
    sizeOutput.writeInt32(output.length - 8);
    var bytes:haxe.io.Bytes = output.getBytes();
    bytes.blit(3, sizeOutput.getBytes(), 0, 4);
    return new Bytes(bytes.getData().length, bytes.getData());
  }";
    return method;
  }

  /**
   * Emit code for encode properties function
   * @param m
   * @return String
   */
  private static function EncodePropsFn(m:Dynamic):String {
    var method:String = "
  public static function " + m.encoder + "(channel:Int, size:Int, fields:Dynamic):Bytes {
    var offset:Int = 0;
    var flags:Int = 0;
    var val:Dynamic;
    var len:Int;
    var varyingSize:Int = 0;";

  var fixedSize:Int = PROPERTIES_OVERHEAD;
  var args:Array<Dynamic> = cast(m.args, Array<Dynamic>);

  for (arg in args) {
    method += AssignArg(arg) + (arg.type == "table" ? CreateTable(arg) : "") + "
    if (val != null) {
      if (" + ValTypeTest(arg) + ") {";
    switch (arg.type) {
    case 'shortstr':
      method += AssignStringLen(arg) + "
        varyingSize += 1;
        varyingSize += " + StringLenVar(arg) + ";";
    case 'longstr':
      method += AssignStringLen(arg) + "
        varyingSize += 4;
        varyingSize += cast(val, String).length;";
    case 'table':
      method += AssignTable(arg, false) + "
        varyingSize += " + TableVar(arg) + ".length;";
    case 'octet':
      method += "
        varyingSize += 1;";
    case 'short':
      method += "
        varyingSize += 2;";
    case 'long':
      method += "
        varyingSize += 4;";
    case 'longlong', // fall through
         'timestamp':
      method += "
        varyingSize += 8;";
      // no case for bit, as they are accounted for in the flags
    }
    method += '
      } else {
        throw new haxe.Exception(\'Field "${arg.name}" is the wrong type; must be ${TypeDesc(arg.type)}\');
      }
    }';
  }

  method += "
    var output:BytesOutput = new BytesOutput();
    output.bigEndian = true;
    output.prepare("+ fixedSize + " + varyingSize);
    output.writeByte(amqp.helper.protocol.Constant.FRAME_HEADER);
    output.writeInt16(channel);
    output.writeInt32(0); // space for size
    output.writeInt32(" + ( m.id << 16 ) + ");
    output.writeInt64(size);
    output.writeInt16(0); // space for flags";

  for (i in 0...args.length) {
    var arg:Dynamic = args[i];
    var flag:Int = FlagAt(i);

    method += AssignArg(arg) + "
    if (val != null) {";
    if (arg.type == 'bit') { // which none of them are ..
      method += "
      if (cast(val, Bool)) {
        flags += " + flag + ";
      }";
    } else {
      method += "
      flags += " + flag + ";";
      // %%% FIXME only slightly different to the method args encoding
      switch (arg.type) {
      case 'octet':
        method += "
      output.writeByte(val);";
      case 'short':
        method += "
      output.writeInt16(val);";
      case 'long':
        method += "
      output.writeInt32(val);";
      case 'longlong',
           'timestamp':
        method += "
      output.writeInt64(val);";
      case 'shortstr':
        method += "
      output.writeByte(cast(val, String).length);
      output.writeString(cast(val, String), haxe.io.Encoding.UTF8);";
      case 'longstr':
        method += "
      output.writeInt32(cast(val, String).length);
      output.writeString(cast(val, String), haxe.io.Encoding.UTF8);";
      case 'table':
        method += "
      output.writeBytes(" + TableVar(arg) + ", 0, " + TableVar(arg) + ".length);";
      default: throw new Exception('Unexpected argument type: ${arg.type}');
      }
    }
    method += "
    }";
  }

  method += "
    output.writeByte(amqp.helper.protocol.Constant.FRAME_END);
    // hacky push in size
    var sizeOutput:BytesOutput = new BytesOutput();
    sizeOutput.bigEndian = true;
    sizeOutput.writeInt32(output.length - 8);
    var bytes:haxe.io.Bytes = output.getBytes();
    bytes.blit(3, sizeOutput.getBytes(), 0, 4);
    // hacky push in flags
    sizeOutput = new BytesOutput();
    sizeOutput.bigEndian = true;
    sizeOutput.writeInt16(flags);
    bytes.blit(19, sizeOutput.getBytes(), 0, 2);
    return new Bytes(bytes.getData().length, bytes.getData());
  }";
  return method;
  }

  /**
   * Emit code for decode properties function
   * @param m
   * @return String
   */
  private static function DecodePropsFn(m:Dynamic):String {
    var args:Array<Dynamic> = cast(m.args, Array<Dynamic>);
    var method:String = "
  public static function " + m.decoder + "(buffer:BytesInput):Dynamic {
    var flags:Int;
    var offset:Int = 2;
    var val:Dynamic;
    var len:Int;

    var bytes:Bytes = Bytes.ofData(buffer.readAll().getData());

    flags = bytes.getUInt16(0);
    if (flags == 0) {
      return {};
    }
    " + FieldsDecl(m.args);
    for (i in 0...args.length) {
      var p:Dynamic = Argument(args[i]);
      var field:String = "fields." + p.name;
      method += "
    if (flags & " + FlagAt(i) + " == " + FlagAt(i) + ") {";
      if (p.type == 'bit') {
        method += "
        " + field + " = true;";
      } else {
        switch(p.type) {
          case 'octet':
            method += "
      val = bytes.get(offset);
      offset++;";
          case 'short':
            method += "
      val = bytes.getUInt16(offset);
      offset += 2;";
          case 'long':
            method += "
      val = bytes.getInt32(offset);
      offset += 4;";
          case 'longlong':
          case 'timestamp':
            method += "
      val = bytes.getInt64(offset);
      offset += 8;";
          case 'longstr':
            method += "
      len = bytes.getInt32(offset);
      offset += 4;
      val = bytes.getString(offset, len);
      offset += len;";
          case 'shortstr':
            method += "
      len = bytes.get(offset);
      offset++;
      val = bytes.getString(offset, len);
      offset += len;";
          case 'table':
            method += "
      len = bytes.getInt32(offset);
      offset += 4;
      val = Codec.DecodeFields(Bytes.ofData(bytes.sub(offset, len).getData()));";
          default:
            throw new Exception('Unexpected type in argument list: ${p.type}');
        }
        method += "
      " + field + " = val;";
      }
      method += "
    }";
    }
    method += "
    return fields;
  }";

    return method;
  }

  /**
   * Emit code for info object
   * @param thing
   * @return String
   */
  private static function InfoObj(thing:Dynamic):String {
    var info = Json.stringify({
      id: thing.id,
      classId: thing.clazzId,
      methodId: thing.methodId,
      name: thing.name,
      args: thing.args
    });
    return "
  public static var " + thing.info + ":Dynamic = Json.parse('" + info + "');";
  }

  /**
   * Helper to generate constant file
   * @param decoded
   */
  static private function GenerateConstantFile(decoded:Dynamic):Void {
    var file:String = "package amqp.helper.protocol;

// This file was autogenerated by spec/GenerateDefinition.hx - Do not modify

class Constant {
  public static inline var FRAME_OVERHEAD:Int = " + FRAME_OVERHEAD + ";
";

    for (constant in cast(decoded.constants, Array<Dynamic>)) {
      file += "
  public static inline var " + ReplaceUnderscore(constant.name) + ":Int = " + constant.value + ";";
    }
    file += "
}
";
    // write constants content to file
    File.saveContent("../src/amqp/helper/protocol/Constant.hx", file);
  }

  /**
   * Main entry point
   */
  static public function main():Void {
    // get arguments
    var args:Array<String> = Sys.args();
    // check for argument length
    if (0 >= args.length) {
      trace("USAGE: haxe --run GenerateDefinition.hx amqp-rabbitmq-0.9.1.json");
      return;
    }
    // read content
    var content:String = File.getContent(args[0]);
    var decoded:Dynamic = Json.parse(content);

    // parse constants and generate class content
    GenerateConstantFile(decoded);

    // prepare domains map
    for (dm in cast(decoded.domains, Array<Dynamic>)) {
      domains.set(dm[0], dm[1]);
    }
    // Generate methods and properties map
    var methods:DynamicAccess<Dynamic> = {}
    var properties:DynamicAccess<Dynamic> = {}
    for (clazz in cast(decoded.classes, Array<Dynamic>)) {
      for (method in cast(clazz.methods, Array<Dynamic>)) {
        var name:String = MethodName(clazz, method);
        var info:String = 'methodInfo' + name;
        methods[name] = {
          id: MethodId(clazz, method),
          name: name,
          methodId: method.id,
          clazzId: clazz.id,
          clazz: clazz.name,
          args: cast(method.arguments, Array<Dynamic>).map(Argument),
          isReply: method.answer,
          encoder: 'encode' + name,
          decoder: 'decode' + name,
          info: info
        };
      }
      if (clazz.properties != null && cast(clazz.properties, Array<Dynamic>).length > 0) {
        var name = PropertiesName(clazz);
        properties[name] = {
          id: clazz.id,
          name: name,
          encoder: 'encode' + name,
          decoder: 'decode' + name,
          info: 'propertiesInfo' + name,
          args: cast(clazz.properties, Array<Dynamic>).map(Argument),
        };
      }
    }
    var encoderDecoder:String = "";
    var infoObj:String = "";
    // write decode and encode method functions
    for (m in methods) {
      infoObj += "
  public static inline var " + m.name + ":Int = " + m.id + ";";
      encoderDecoder += DecoderFn(m) + "
";
      encoderDecoder += EncoderFn(m) + "
";
      infoObj += InfoObj(m);
    }
    for (p in properties ) {
      infoObj += "
  public static inline var " + p.name + ":Int = " + p.id + ";";
      encoderDecoder += EncodePropsFn(p) + "
";
      encoderDecoder += DecodePropsFn(p) + "
";
      infoObj += InfoObj(p);
    }

    var functions:String = "
  public static function decode(id:Int, buf:BytesInput): Dynamic {
    switch(id) {";
    for (m in methods) {
      functions += "
      case " + m.id + ": return " + m.decoder + "(buf);";
    }
    for (p in properties) {
      functions += "
      case " + p.id + ": return " + p.decoder + "(buf);";
    }
    functions += "
      default: throw new haxe.Exception('Unknown class/method id $id');
    }
  }
  public static function encodeMethod(id:Int, channel:Dynamic, fields:Dynamic):Bytes {
    switch(id) {";
    for (m in methods) {
      functions += "
      case " + m.id + ": return " + m.encoder + "(channel, fields);";
    }
    functions += "
      default: throw new haxe.Exception('Unknown class/method id $id');
    }
  }
  public static function encodeProperties(id:Int, channel:Dynamic, size:Dynamic, fields:Dynamic):Bytes {
    switch (id) {";
    for (p in properties) {
      functions += "
      case " + p.id + ": return " + p.encoder + "(channel, size, fields);";
    }
    functions += "
      default: throw new haxe.Exception('Unknown class/properties id $id');
    }
  }
  public static function info(id:Int):Dynamic {
    switch (id) {";
    for (m in methods) {
      functions += "
      case " + m.id + ": return " + m.info + ";";
    }
    for (p in properties) {
      functions += "
      case " + p.id + ": return " + p.info + ";";
    }
    functions += "
      default: throw new haxe.Exception('Unknown method/properties id $id');
    }
  }";

    var file:String = "package amqp.helper.protocol;

import haxe.Json;
import format.tools.BitsInput;
import format.tools.BitsOutput;
import amqp.Codec;
import amqp.helper.Bytes;
import amqp.helper.BytesInput;
import amqp.helper.BytesOutput;

// This file was autogenerated by spec/GenerateDefinition.hx - Do not modify

class EncoderDecoderInfo {
  private static var SCRATCH:BytesOutput = new BytesOutput();";
    // append info objects
    file += infoObj;
    file += encoderDecoder;
    file += functions;
    file += "
}
";
    File.saveContent("../src/amqp/helper/protocol/EncoderDecoderInfo.hx", file);
  }
}

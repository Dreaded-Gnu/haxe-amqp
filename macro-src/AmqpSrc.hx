#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.FileSystem;

class AmqpSrc {
  public static function apply() {
    for (cp in Context.getClassPath()) {
      var path:String = FileSystem.absolutePath(cp);
      var index:Int = path.indexOf('haxe-amqp');
      var index2:Int = path.indexOf('macro-src');
      if (index != -1 && index2 != -1) {
        Compiler.addClassPath(path.substr(0, index2) + 'src');
        Compiler.addClassPath(path.substr(0, index2) + 'src/promises/src');
        break;
      }
    }
  }
}
#end

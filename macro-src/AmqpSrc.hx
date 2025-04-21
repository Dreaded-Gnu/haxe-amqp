#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.FileSystem;
import haxe.io.Path;

class AmqpSrc {
  /**
   * Apply function to prepare class paths
   */
  public static function apply() {
    // iterate over class paths
    for (cp in Context.getClassPath()) {
      // get absolute path
      var path:String = FileSystem.absolutePath(cp);
      // get index of project and macro-src
      var index:Int = path.lastIndexOf('amqp');
      var index2:Int = path.lastIndexOf('macro-src');
      // handle found
      if (index != -1 && index2 != -1) {
        // Add amqp class path
        Compiler.addClassPath(Path.join([path.substr(0, index2), 'src',]));
        // add promises submodule to class path
        Compiler.addClassPath(Path.join([path.substr(0, index2), 'src', 'promises', 'src',]));
        // stop the loop
        break;
      }
    }
  }
}
#end

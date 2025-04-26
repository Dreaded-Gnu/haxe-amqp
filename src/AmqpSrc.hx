package;

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
    Compiler.addClassPath(FileSystem.absolutePath(Context.resolvePath(Path.join(["..", "thirdparty", "promises", "src"]))));
  }
}
#end

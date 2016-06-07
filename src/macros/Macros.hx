package macros;
import haxe.io.Path;
#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.Ref;
import haxe.Resource;
import haxe.xml.Fast;
#end


/**
 * ...
 * @author Teun
 */
class Macros
{
	
	macro public static function buildXsd() 
	{
		var xsd = Xml.parse(Resource.getString("vmap_xsd")).firstElement();
		if (xsd.nodeName == "xs:schema") {
			trace('parsing xsd schema for ${xsd.get("targetNamespace")}');
			parseNode(xsd);
		}
		
		return macro null;
	}
	
	private static function parseNode(x:Xml) {
			for (el in x.elements()) {
				switch(el.nodeName) {
					case "xs:annotation": trace("[" + el.parent.get("name") + "] : " + el.firstElement().firstChild().nodeValue);
					case "xs:element": parseTypeElement(el);
					case "xs:complexType": parseTypeComplex(el);
					default:
				}
				
			}
		
			
	}
	
	private static function parseTypeElement(x:Xml) {
		trace("parse elementType");
		trace("\t" + x.nodeName + " " + x.get("name"));
		trace(x.firstElement());
		parseNode(x);
	}
	
	private static function parseTypeComplex(x:Xml) {
		trace("parse complexType");
		trace("\t" + x.nodeName + " " + x.get("name"));
	}
	
	macro public static function GetGitShortHead() 
	{
		var version:String = "1.0";
		var date = Date.now().toString();
        var pos = haxe.macro.Context.currentPos();
		
		trace(Sys.getEnv("PATH"));
		var p = try new sys.io.Process("git", ["rev-parse" ,"--short", "HEAD"]) catch ( e : Dynamic ) { trace("no git command found: " +  e); return { expr : EConst(CString("")), pos : pos }; };
		var output = "v."+version + "," + date + ",Git short SHA1:" + p.stderr.readAll().toString() + p.stdout.readAll().toString();
		//Sys.command("git rev-parse --short HEAD > gitversion.txt");
		//var output = sys.io.File.read("svnversion.txt").readLine();
		output = output.split("\r").join("").split("\n").join("");

        return { expr : EConst(CString(output)), pos : pos };
	}
	
	/**
	 * Import files as compressed base64.
	 * Use path relative to any of the include folders
	 * @param	files
	 * @return
	 */
	macro static public function importFilesAsB64String(files:Array<String>):Expr 
	{
		trace("[importFilesAsB64String] Called from " + Context.getLocalModule());
		
		var retval:Array<Dynamic<{file:String, data:String}>> = new Array<Dynamic<{file:String, data:String}>>();
		trace("[importFilesAsB64String] importing from " + Sys.getCwd());
		for (s in files) {
			try {
				s = Context.resolvePath(s); //resolve the actual path from included directories
				var fin = sys.io.File.read(s, false);
				trace("[importFilesAsB64String] importing and compressing: " + s);
				var object:Dynamic<{file:String, data:String}> = { };
				Reflect.setField(object, "file", s);
				Reflect.setField(object, "data", haxe.crypto.Base64.encode(haxe.zip.Compress.run(fin.readAll(), 5)));
				retval.push( object );
				fin.close();
			}catch (e:Error) {
				trace(e.message);
			}
			
		}
		// an "ExprDef" is just a piece of a syntax tree. Something the compiler
		// creates itself while parsing an a .hx file
		return macro $v { retval };
	}	
	
	macro public static function GetBuildHost() 
	{	
		return { expr : EConst(CString(sys.net.Host.localhost())), pos : haxe.macro.Context.currentPos() };
	}
	
	macro public static function inject_build() :Array<Field>
	{	
		var getFiles:String->Void = null;
		getFiles = function(path) {	
			if (path.length > 0 && path.indexOf("dashplayer") > -1) { //only dashplayer for now
				path = Path.addTrailingSlash(path);	
				for (file in sys.FileSystem.readDirectory(path)) {
					//trace(file);
					if(!sys.FileSystem.isDirectory(path + file)){
						//trace('fffound $path$file');
						var fi = sys.io.File.read('$path$file', false);					
						var regex:EReg = new EReg("package (.*);", "");
						var fileData = fi.readAll().toString();
						
						if (regex.match(fileData) && 
							fileData.indexOf("interface ") == -1  && 
							fileData.indexOf("extern ") == -1  && 
							fileData.indexOf("@:native(") == -1) { //only dashplayer for now
							var classname = new Array<String>(); 
							var ns = StringTools.trim(regex.matched(1));
							if (ns.length > 0) {
								classname.push(ns);
							}
							classname.push(Path.withoutExtension(file));
							
							Compiler.addMetadata("@:build(Macros._inject_callback())", classname.join("."));
						}
						fi.close();
					}else {
						getFiles(path + file);
					}
				}
			}
		}
		for (path in Context.getClassPath()) {
			//recursive get files
			getFiles(path);
		}
		
		return Context.getBuildFields();
	}
	
	macro public static function _inject_callback() :Array<Field>
	{	
		// get the fields of the class
		var fields:Array<Field> = Context.getBuildFields();
		
		for(field in fields)
		{
			// look for methods
			switch(field.kind)
			{
				// yup, found a method!
				case FFun(func):
				{
					
					var methodName:String = field.name;
					//trace(Context.getLocalType()  + " " + methodName);
					//inject only for dashplayer.drm:
					if (Std.string(Context.getLocalType().getParameters()[0]).indexOf("dashplayer.drm") != -1) {
					
						trace("inject -> "  + Context.getLocalType()  + " " + methodName);
						func.expr = macro {
							trace($v { methodName } + " was called");
							$ { func.expr };
						};
					}
					
				}

				// ignore variables and properties
				default: {}
			}
		}
		return fields;
	}
	
	
}
package;

import dom4.DOMParser;
import haxe.Json;
import haxe.Resource;
import haxe.xml.Fast;
import haxe.xml.Printer;
#if js
import js.Node;
#end
import macros.Macros;
import promhx.Deferred;
import promhx.Promise;

/**
 * ...
 * @author tecteun
 */
class Main 
{
	
	
	static function main() 
	{
		
		//https://github.com/oklahomaok/AppStoreReview/blob/master/AppStore/ReviewScraper.cs
		test().then(function(d:Dynamic) { 
			var f = new Fast(Xml.parse(d));
			for (a in f.node.Document.node.View.node.ScrollView.node.VBoxView.node.View.node.MatrixView.node.VBoxView.node.VBoxView.nodes.VBoxView) {
				//trace(a.x.toString());
				if(a.hasNode.TextView){
					trace(a.x.toString());
					//trace(a.node.TextView.node.SetFontStyle.innerData.toString());	
				}
			}
			
			//trace(hxdom.HtmlSerializer.run(cast document.querySelector("Document View ScrollView VBoxView View MatrixView VBoxView"))); 
			
			
		} );
		//Macros.buildXsd();
		#if js
			var server:NodeHttpServer = Node.http.createServer(listener2);
			//Required for Azure web service compat.
			var port = Sys.getEnv("PORT");
			server.listen(port == null ? 8080 : untyped port);
		#end
		#if cs
			trace(callMe());
		#end
	}
	
	#if cs
	@:meta(HttpPost)
	static public function callMe() {
		var retval = null;
		
		try{
			getVFDMetadata(Sys.args()[0]).then(function(d:Dynamic) { retval = d; } );
		}catch (e:Dynamic) { retval = e; };
		return retval;
	}
	#end
	
	
	#if js
	
	static private function listener2(incoming:NodeHttpServerReq, response:NodeHttpServerResp):Void {
		test().then(function(d:Dynamic) { 
			var contentSink = new dom4.utils.BasicContentSink();
			var dp = new DOMParser(contentSink);
			var document = dp.parseFromString(d, "text/xml");
			
			response.end(document.querySelector("/document/view").textContent); 
			
		} );
	}
	
	static private function test(?page:Int):Promise<Dynamic> {
		
		var uri = 'https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=411290027&pageNumber=0&sortOrdering=2&type=Purple+Software';
		trace('Fetch file\n\t[$uri]');
		var d:Deferred<Dynamic> = new Deferred<Dynamic>();
		var p:Promise<Dynamic> = d.promise();
		var loader = new haxe.Http(uri);
		loader.setHeader("User-Agent", "iTunes/9.2 (Macintosh; U; PPC Mac OS X 10.6)");
		loader.setHeader("X-Apple-Store-Front", "143452");
		loader.onData = function(data:String) {
			if (null != data)
					d.resolve(data);
		};
		loader.onError = function(err) {
			trace('Error\n${err}');
			d.throwError('$err');
		}
		
		loader.request(false);
		return p;
	}
	
	
	//http://www.rtl.nl/system/s4m/vfd/version=2/fun=abstract/uuid=8e7ab17a-cfcc-447f-b9a2-2b0e00eccc80/
	static private function listener(incoming:NodeHttpServerReq, response:NodeHttpServerResp):Void {
		// Start the vmap xml.
		var Vmap =  Xml.parse('<vmap:VMAP xmlns:vmap="http://www.iab.net/videosuite/vmap" version="1.0"></vmap:VMAP>');
		
		if (incoming.url.indexOf("?") > -1) {
			var raq = incoming.url.split("?");
			trace('aap ${raq.length}');
			if (raq.length > 1) {
				var qs = Node.querystring.parse(raq[1]);
				if (Reflect.hasField(qs , "uuid")) {
					
					getVFDMetadata(Reflect.field(qs, 'uuid')).then(function(d:Dynamic) { 
						
						// Create the ad break.
						var adBreak = Xml.createElement('vmap:AdBreak');
						adBreak.set('breakType', "linear");
						adBreak.set('breakId', "prerolls");
						adBreak.set('timeOffset', "start");	
						
						Vmap.firstElement().addChild(adBreak);
						
						var adBreak = Xml.createElement('vmap:AdBreak');
						adBreak.set('breakType', "linear");
						adBreak.set('breakId', "midrolls");
						adBreak.set('timeOffset', "start");	
						
						Vmap.firstElement().addChild(adBreak);
						
						var adBreak = Xml.createElement('vmap:AdBreak');
						adBreak.set('breakType', "linear");
						adBreak.set('breakId', "postrolls");
						adBreak.set('timeOffset', "start");	
						
						Vmap.firstElement().addChild(adBreak);
						
						response.write('<?xml version="1.0" encoding="utf-8"?>\n');
						response.write('<!-- RTL.nl VMAP generator: ${Macros.GetGitShortHead()} -->\n');
						
						/*
						response.write("<data>\n");
						
						if (Reflect.hasField(d, "material")) {
							var materials = Reflect.field(d, "material");
							if(null != materials){
								response.write('<breakpoints>${materials[0].breakpoints}</breakpoints>\n');
							}
						}
						
						response.write("<json>\n" + Json.stringify(d, null, " ") +"\n</json>\n");	
						response.end("<data>");
						*/
						response.end(Printer.print(Vmap, true));	
						
						
					} ).errorThen(function(err:Dynamic) {
						handleError(response, err);
					});
				}else {
					return handleError(response, "Error: no querystring variables found");
				}
				
			}else {
				return handleError(response, "Error: empty querystring found");
			}
		}else {
			return handleError(response, "Error: no querystring found");	
		}
		
		
	
	}
	
	static private inline function handleError(response:NodeHttpServerResp, error:String) {
		response.writeHead(404, { 'Content-Type': 'text/html' } );
		response.end(StringTools.replace(haxe.Resource.getString("error_template"), "[#replace#]", error));
		//response.write("------------API-Error--------------");
		//response.end("\n\t" + error);
	}
	#end
	
	static private function getVFDMetadata(uuid:String):Promise<Dynamic> {
		var uri = 'http://www.rtl.nl/system/s4m/vfd/version=2/fun=abstract/uuid=$uuid/';
		trace('Fetch file\n\t[$uri]');
		var d:Deferred<Dynamic> = new Deferred<Dynamic>();
		var p:Promise<Dynamic> = d.promise();
		var loader = new haxe.Http(uri);
		loader.onData = function(data:String) {
			try {
				var obj = Json.parse(data);
				if (null != obj)
					d.resolve(obj);
			}catch (err:Dynamic) {
				trace('JSON parsing error\n\t$err\n\t$data');
				d.throwError('$err\n$data');
			}
		};
		loader.onError = function(err) {
			trace('Error\n${err}');
			d.throwError('$err');
		}
		
		loader.request(false);
		return p;
	}
}
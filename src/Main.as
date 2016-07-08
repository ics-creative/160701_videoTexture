package
{
	import com.adobe.utils.AGALMiniAssembler;
	import com.bit101.components.ComboBox;
	
	import flash.display.Sprite;
	import flash.display.Stage3D;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProfile;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DRenderMode;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.textures.VideoTexture;
	import flash.events.Event;
	import flash.events.VideoTextureEvent;
	import flash.geom.Matrix3D;
	import flash.media.Camera;
	import flash.system.Capabilities;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.utils.ByteArray;
	
	/**
	 * @author Kentaro Kawakatsu
	 */
	public final class Main extends Sprite
	{
		private var mode:uint = 0;
		private var combo:ComboBox;
		//
		private var stage3D:Stage3D;
		private var context3D:Context3D;
		//
		private var programList:Vector.<Program3D>;
		private var vertexBuffer:VertexBuffer3D;
		private var indexBuffer:IndexBuffer3D;
		private var mtx:Matrix3D;
		//
		private var camera:Camera;
		private var videoTexture:VideoTexture;
		
		/**
		 * Constructor.
		 */
		public function Main():void
		{
			stage.frameRate = 60;
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			// check VideoTexture support
			if (!Context3D.supportsVideoTexture) 
			{
				var tf:TextField = new TextField();
				tf.autoSize = TextFieldAutoSize.LEFT;
				addChild(tf);
				const message:String = "VideoTexture is not supported on your PC.";
				var format:TextFormat = new TextFormat("_sans", 14, 0x000000);
				tf.defaultTextFormat = format;
				tf.text = message;
				tf.x = (stage.stageWidth - tf.textWidth) / 2;
				tf.y = (stage.stageHeight - tf.textHeight) / 2;
				trace(message);
				return;
			}
			stage3D = stage.stage3Ds[0];
			stage3D.x = 0;
			stage3D.y = 0;
			stage3D.addEventListener(Event.CONTEXT3D_CREATE, contextCreateHandler);
			stage3D.requestContext3D(Context3DRenderMode.AUTO, Context3DProfile.STANDARD_CONSTRAINED);
		}
		
		private function contextCreateHandler(e:Event):void
		{
			context3D = stage3D.context3D;
//			context3D.enableErrorChecking = true;
			context3D.configureBackBuffer(stage.stageWidth, stage.stageHeight, 0, false);
			
			// create
			createShaders();
			setConstant();
			setBuffer();
			
			// UI
			combo = new ComboBox(this, 0, 0, "normal", ["normal", "monochrome", "neg", "sepia"]);
			combo.numVisibleItems = 4;
			combo.x = stage.stageWidth - combo.width - 10;
			combo.y = 10;
			combo.addEventListener(Event.SELECT, combo_seletHandler);
			
			// camera
			camera = Camera.getCamera();
			camera.setMode(stage.stageWidth, stage.stageHeight, 60);
			videoTexture = context3D.createVideoTexture();
			videoTexture.attachCamera(camera);
			videoTexture.addEventListener(VideoTextureEvent.RENDER_STATE, videoTexture_renderStateHandler);
			
			// resize
			stage.addEventListener(Event.RESIZE, stage_resizeHandler);
		}
		
		private function stage_resizeHandler(event:Event):void 
		{
			context3D.configureBackBuffer(stage.stageWidth, stage.stageHeight, 0, false);
			camera.setMode(stage.stageWidth, stage.stageHeight, 60);
			combo.x = stage.stageWidth - combo.width - 10;
		}
		
		private function videoTexture_renderStateHandler(event:VideoTextureEvent):void
		{
			context3D.setTextureAt(0, videoTexture);
			setMode(0);
			
			// start rendering
			addEventListener(Event.ENTER_FRAME, enterframeHandler);
		}
		
		/**
		 * rendering loop.
		 */
		private function enterframeHandler(event:Event):void
		{
			context3D.clear(0, 0, 0, 1);
			context3D.drawTriangles(indexBuffer);
			context3D.present();
		}
		
		/**
		 * event is fired when combobox is selected.
		 */
		private function combo_seletHandler(event:Event):void
		{
			setMode(combo.selectedIndex);
		}
		
		/**
		 * set shader program for selected effect.
		 */
		private function setMode($mode:uint):void
		{
			mode = $mode;
			context3D.setProgram(programList[mode]);
			switch (mode)
			{
				case 0: 
					break;
				case 1: 
					context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, Vector.<Number>([4.0, 0.0, 0.0, 0.0]));
					break;
				case 2: 
					context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, Vector.<Number>([1.0, 0.0, 0.0, 0.0]));
					break;
				case 3: 
					context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, Vector.<Number>([0.9, 0.7, 0.4, 0]));
					context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, Vector.<Number>([0.298912, 0.586611, 0.114478, 0]));
					break;
				default: 
			}
		}
		
		/**
		 * create Stage3D shader programs.
		 */
		private function createShaders():void
		{
			// create shaders
			var agalAssembler:AGALMiniAssembler = new AGALMiniAssembler();
			
			// vertex
			var vertexShader:ByteArray = agalAssembler.assemble(Context3DProgramType.VERTEX, "m44 op, va0, vc0 \n" + "mov v0, va1\n");
			
			// fragment
			var fragmentShader:ByteArray;
			var program:Program3D;
			programList = new Vector.<Program3D>();
			
			var code:Array;
			
			// normal
			code = [
				"mov ft0 v0",
				"tex ft0, ft0, fs0<2d,clamp,linear>",
				"mov oc, ft0",
			];
			fragmentShader = agalAssembler.assemble(Context3DProgramType.FRAGMENT, code.join("\n"));
			program = context3D.createProgram();
			program.upload(vertexShader, fragmentShader);
			programList[0] = program;
			
			// monochrome
			code = [
				"mov ft0 v0",
				"tex ft0, ft0, fs0<2d,clamp,linear>",
				"add ft1.x, ft0.x, ft0.y",
				"add ft1.x, ft1.x, ft0.z",
				"div ft1.x, ft1.x, fc0.x",
				"mov ft0.xyz, ft1.x",
				"mov oc, ft0",
			];
			fragmentShader = agalAssembler.assemble(Context3DProgramType.FRAGMENT, code.join("\n"));
			program = context3D.createProgram();
			program.upload(vertexShader, fragmentShader);
			programList[1] = program;
			
			// neg
			code = [
				"mov ft0 v0",
				"tex ft0, ft0, fs0<2d,clamp,linear>",
				"sub ft0, fc0.x, ft0",
				"mov oc, ft0",
			];
			fragmentShader = agalAssembler.assemble(Context3DProgramType.FRAGMENT, code.join("\n"));
			program = context3D.createProgram();
			program.upload(vertexShader, fragmentShader);
			programList[2] = program;
			
			// sepia
			code = [
				"mov ft0 v0",
				"tex ft0, ft0, fs0<2d,clamp,linear>",
				"mul ft0.xyz, ft0.xyz, fc1",
				"add ft1.x, ft0.x, ft0.y",
				"add ft1.x, ft1.x, ft0.z",
				"mov ft0.xyz, ft1.x",
				"mul ft0.xyz, ft0.xyz, fc0",
				"mov oc, ft0",
			];
			fragmentShader = agalAssembler.assemble(Context3DProgramType.FRAGMENT, code.join("\n"));
			program = context3D.createProgram();
			program.upload(vertexShader, fragmentShader);
			programList[3] = program;
		}
		
		/**
		 * set constants for shaders.
		 */
		private function setConstant():void
		{
			// vc
			mtx = new Matrix3D();
			context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, mtx, false);
		}
		
		/**
		 * create and set buffers for shaders.
		 */
		private function setBuffer():void
		{
			// vertex buffer
			vertexBuffer = context3D.createVertexBuffer(4, 4);
			vertexBuffer.uploadFromVector(Vector.<Number>([-1, -1, 0, 1, -1, 1, 0, 0, 1, -1, 1, 1, 1, 1, 1, 0]), 0, 4);

			// index buffer
			indexBuffer = context3D.createIndexBuffer(6);
			indexBuffer.uploadFromVector(Vector.<uint>([0, 1, 2, 1, 2, 3]), 0, 6);
			
			context3D.setVertexBufferAt(0, vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_2);
			context3D.setVertexBufferAt(1, vertexBuffer, 2, Context3DVertexBufferFormat.FLOAT_2);
		}
	}
}
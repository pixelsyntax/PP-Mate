package;


import openfl.display.Sprite;


class Main extends Sprite {
	
	var appmode : AppMode;
	var titleFrames : Int;
	var theGame : Game;
	var theTitle : openfl.display.Bitmap;

	public function new () {
		
		super ();
		
		appmode = AppMode.title;

		scaleX = 4;
		scaleY = 4;
		titleFrames = 0;
		theTitle = new openfl.display.Bitmap( openfl.Assets.getBitmapData("assets/title.png"));
		addChild( theTitle );

		addEventListener( openfl.events.Event.ENTER_FRAME, onEnterFrame );
		addEventListener( openfl.events.MouseEvent.CLICK, onMouseClick );
		
	}

	function onEnterFrame( e : openfl.events.Event ){

		++titleFrames;
		if ( appmode == game && ( theGame == null || theGame.isExpired ) )
			setAppMode( title );

	}
	
	function onMouseClick( e : openfl.events.MouseEvent ){

		if ( appmode == title && titleFrames > 60 ){
			setAppMode( game );
		}

	}

	function setAppMode( newMode : AppMode ){

		switch( newMode ){
			case game:
				theTitle.visible = false;
				theGame = new Game();
				addChild( theGame );
			case title:
				theTitle.visible = true;
				if ( theGame != null ){
					removeChild( theGame );
					theGame = null;
				}
				titleFrames = 0;
		}

		appmode = newMode;

	}

	
}

enum AppMode {

	title;
	game;

}
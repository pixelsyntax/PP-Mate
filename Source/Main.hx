package;


import openfl.display.Sprite;


class Main extends Sprite {
	
	
	public function new () {
		
		super ();
		
		scaleX = 4;
		scaleY = 4;

		var game = new Game();
		addChild( game );
		
		
	}
	
	
}
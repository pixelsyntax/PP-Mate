package;

import openfl.display.Sprite;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.display.Tile;
import openfl.display.Tileset;
import openfl.display.Tilemap;

class Game extends Sprite {
	
	var gameview : Tilemap;

	public function new(){

		super();
		setupGUI();
		// gameview = new Tilemap()

	}

	function setupGUI(){

		var guiBG = new Bitmap( Assets.getBitmapData("assets/background.png") );
		addChild( guiBG );

	}

}


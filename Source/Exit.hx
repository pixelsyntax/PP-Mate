package;

import openfl.display.Tile;

class Exit extends Tile {
	
	var frame : Int;
	var baseID : Int;
	var radius : Float;

	public function new(){

		frame = 0;
		baseID = Game.singleton.spriteIndices.get( exit );
		super( baseID, 128, 5 * 16 );
		radius = 24;
		originX = radius;
		originY = radius;

	}

	public function tick(){

		frame = ( frame + 1 ) % 4;
		id = baseID + frame;
		rotation += 5;

		var dx = x - Game.singleton.player.x;
		var dy = y - Game.singleton.player.y;

		Game.singleton.vx += dx / 240;
		Game.singleton.vy += dy / 240;

	}

}
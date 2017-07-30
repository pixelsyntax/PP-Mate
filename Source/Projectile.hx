package;

import openfl.display.Tile;

class Projectile extends Tile {
	
	public var vx : Float;
	public var vy : Float;
	public var isExpired : Bool;

	public function new( tileIndex : Int, x : Float, y : Float, vx : Float, vy : Float, angle : Float ){

		super( tileIndex, x, y );
		originX = 8;
		originY = 8;
		rotation = angle;
		this.vx = vx;
		this.vy = vy;
		isExpired = false;
	}

}
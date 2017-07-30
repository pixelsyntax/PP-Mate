package;

import openfl.display.Tile;

class Enemy extends Tile {
	
	public var radius : Float;
	public var health : Int;
	public var isExpired : Bool;
	public var enemyType : Enemy.EnemyType;
	public var vx : Float;
	public var vy : Float;
	var baseID : Int;

	public function new( enemyType : EnemyType, x : Float, y : Float ){

		isExpired = false;
		this.enemyType = enemyType;
		vx = 0;
		vy = 0;
		
		switch( enemyType ){
			default:
				baseID = 0;
				radius = 1;
				health =  1;
			case circle:
				baseID = Game.singleton.spriteIndices.get(enemy_circle_l);
				radius = 8;
				health = 1;
		}

		super( baseID, x, y );
		originX = Math.floor( radius );
		originY = Math.floor( radius );
	}

	public function receiveHit(){
		health -= 1;
		if ( health <= 0 )
			isExpired = true;
	}

	public function tick(){

		switch( enemyType ){
			default:
				return;
			case circle:
				var dx = Game.singleton.player.x - x; 
				var dy = Game.singleton.player.y - y; 
				if ( dx > 16 ){
					vx += 0.05;
					id = baseID + 1;
				}
				if ( dx < -16 ){
					vx -= 0.05;
					id = baseID;
				}
				if ( dy > 16 )
					vy += 0.05;
				if ( dy < -16 )
					vy -= 0.05;

				vx = Math.min(Math.max(vx, -1), 1);
				vy = Math.min(Math.max(vy, -1), 1);
		}

	}

}

enum EnemyType {
	circle;
	triangle;
	square;
	pentagon;
	hexagon;
	octagon;
}
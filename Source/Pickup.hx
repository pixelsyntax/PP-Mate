package;

import openfl.display.Tile;

class Pickup extends Tile {
	
	public var isExpired : Bool;
	public var maxSpeed : Float;
	public var vx : Float;
	public var vy : Float;
	public var pickupType : PickupType;
	public var baseID : Int;
	public var lifetime : Int;
	public var radius : Float;

	public function new( pickupType : PickupType, x : Float, y : Float ){

		super( 0, x, y );

		this.pickupType = pickupType;
		switch ( pickupType ){
			default: //power pickup
				baseID = Game.singleton.spriteIndices.get( pickup_power_a );
				maxSpeed = 0.5;
				originX = 8;
				originY = 8;
				lifetime = 180;
				radius = 8;
			case weapon_basic:
				baseID = Game.singleton.spriteIndices.get( pickup_weapon_a );
				maxSpeed = 0;
				originX = 16;
				originY = 16;
				radius = 16;
				lifetime = 100000;
			case weapon_rapid:
				baseID = Game.singleton.spriteIndices.get( pickup_weapon_c );
				maxSpeed = 0;
				originX = 16;
				originY = 16;
				radius = 16;
				lifetime = 100000;
			case weapon_multi:
				baseID = Game.singleton.spriteIndices.get( pickup_weapon_b );
				maxSpeed = 0;
				originX = 16;
				originY = 16;
				radius = 16;
				lifetime = 100000;
			case weapon_beam:
				baseID = Game.singleton.spriteIndices.get( pickup_weapon_d );
				maxSpeed = 0;
				originX = 16;
				originY = 16;
				radius = 16;
				lifetime = 100000;
			
		}	

		id = baseID;
		vx = 0;
		vy = 0;


	}

	public function tick(){

		switch( pickupType ){
			default:
				return;
			case power:
				var dx = Game.singleton.player.x - x;
				var dy = Game.singleton.player.y - y;
				if ( dx > 8 )
					vx += 0.02;
				else if ( dx < -8 )
					vx -= 0.02;
				else 
					vx *= 0.95;

				if ( dy > 8 )
					vy += 0.02;
				else if ( dy < -8 )
					vy -= 0.02;
				else 
					vy *= 0.95;

						
		}

	}

}

enum PickupType {
	power;
	weapon_basic;
	weapon_multi;
	weapon_rapid;
	weapon_beam;
}
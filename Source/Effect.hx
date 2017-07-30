package;

import openfl.display.Tile;

class Effect extends Tile {
	
	public var isExpired : Bool;
	public var frame : Int;
	public var maxFrame : Int;
	public var effectType : Effect.EffectType;
	public var baseID : Int;

	public function new( effectType : EffectType, x : Float, y : Float ){

		
		frame = -1;
		this.effectType = effectType;

		maxFrame = 2;
		switch( effectType ){

			case explosion_tiny:
				baseID = Game.singleton.spriteIndices.get(explosion_tiny);
				originX = 4;
				originY = 4;

			case explosion_small:
				baseID = Game.singleton.spriteIndices.get(explosion_small);
				originX = 8;
				originY = 8;

			case explosion_medium:
				baseID = Game.singleton.spriteIndices.get(explosion_medium);
				originX = 16;
				originY = 16;

			case explosion_large:
				baseID = Game.singleton.spriteIndices.get(explosion_large);
				originX = 24;
				originY = 24;

			case particle_portal:
				baseID = Game.singleton.spriteIndices.get(particle_portal);
				originX = 4;
				originY = 4;
				maxFrame = 3;

		}

		super(baseID,x,y);
	}

	public function tick(){

		++frame;
		
		if ( frame >= maxFrame )
			isExpired = true;
		else
			id = baseID + frame;

		if ( effectType == particle_portal )
			y -= Math.random() * 2;

	}

}

enum EffectType {
	
	explosion_tiny;
	explosion_small;
	explosion_medium;
	explosion_large;
	particle_portal;

}


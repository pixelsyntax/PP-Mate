package;

import openfl.display.Tile;

class Enemy extends Tile {
	
	public var radius : Float;
	public var health : Int;
	public var maxHealth : Int;
	public var isExpired : Bool;
	public var enemyType : Enemy.EnemyType;
	public var vx : Float;
	public var vy : Float;
	var baseID : Int;
	var painFrames : Int;
	var reloadTime : Int;
	var sequence : Int;

	public function new( enemyType : EnemyType, x : Float, y : Float ){

		super( 0, x, y );

		isExpired = false;
		this.enemyType = enemyType;
		vx = 0;
		vy = 0;
		sequence = 0;
		reloadTime = 60;

		switch( enemyType ){
			default:
				baseID = 0;
				radius = 1;
				health =  1;
			case circle:
				baseID = Game.singleton.spriteIndices.get(enemy_circle_l);
				radius = 8;
				health = 1;
			case triangle:
				baseID = Game.singleton.spriteIndices.get(enemy_triangle_l);
				radius = 16;
				health = 3;
			case square:
				baseID = Game.singleton.spriteIndices.get(enemy_square_l);
				radius = 18;
				health = 4;
			case pentagon:
				baseID  = Game.singleton.spriteIndices.get(enemy_pentagon);
				radius = 26;
				health = 16;

				Game.singleton.spawnEnemy( circle, x+32, y );
				Game.singleton.spawnEnemy( circle, x-32, y );
			case hexagon:
				baseID  = Game.singleton.spriteIndices.get(enemy_hexagon);
				radius = 26;
				health = 32;
				Game.singleton.spawnEnemy( triangle, x+48, y );
				Game.singleton.spawnEnemy( triangle, x-48, y );
			case octagon:
				baseID  = Game.singleton.spriteIndices.get(enemy_octagon);
				radius = 32;
				health = 64;
				Game.singleton.spawnEnemy( square, x+64, y );
				Game.singleton.spawnEnemy( square, x-64, y );
		}

		id = baseID;
		maxHealth = health;
		originX = Math.floor( radius );
		originY = Math.floor( radius );
		painFrames = 0;
	}

	public function receiveHit(){
		painFrames += 4;
		health -= 1;
		if ( health <= 0 && !isExpired){
			isExpired = true;
			if ( enemyType == triangle || enemyType == hexagon )
				Game.singleton.enemyShoot( this );
			if ( enemyType == pentagon ){
				if ( Math.random() < 0.5 )
					Game.singleton.spawnWeaponPickup( Game.PlayerWeapon.weapon_basic, x, y );
				else
					Game.singleton.spawnWeaponPickup( Game.PlayerWeapon.weapon_multi, x, y );
			}
			if ( enemyType == hexagon ){
				if ( Math.random() < 0.5 )
					Game.singleton.spawnWeaponPickup( Game.PlayerWeapon.weapon_multi, x, y );
				else
					Game.singleton.spawnWeaponPickup( Game.PlayerWeapon.weapon_rapid, x, y );
			}
			if ( enemyType == octagon ){
				if ( Math.random() < 0.5 )
					Game.singleton.spawnWeaponPickup( Game.PlayerWeapon.weapon_rapid, x, y );
				else
					Game.singleton.spawnWeaponPickup( Game.PlayerWeapon.weapon_multi, x, y );
			}
		}
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

				vx = Math.min(Math.max(vx, -1.5), 1.5);
				vy = Math.min(Math.max(vy, -1.5), 1.5);
				if ( painFrames > 0 )
					id = baseID + 2;
			case triangle:
				var dx = Game.singleton.player.x - x; 
				var dy = Game.singleton.player.y - y; 
				if ( dx > 16 ){
					vx += 0.03;
					id = baseID + 1;
				}
				if ( dx < -16 ){
					vx -= 0.03;
					id = baseID;
				}
				if ( dy > 16 )
					vy += 0.03;
				if ( dy < -16 )
					vy -= 0.03;

				vx = Math.min(Math.max(vx, -1), 1);
				vy = Math.min(Math.max(vy, -1), 1);
				if ( painFrames > 0 )
					id = baseID + 2;

			case square:
				var dx = Game.singleton.player.x - x; 
				var dy = Game.singleton.player.y - y; 

				if ( dx > 16 ){
					vx -= 0.02;
					id = baseID + 1;
				}
				if ( dx < -16 ){
					vx += 0.02;
					id = baseID;
				}
				if ( dy > 16 )
					vy -= 0.02;
				if ( dy < -16 )
					vy += 0.02;

				vx = Math.min(Math.max(vx, -0.7), 0.7);
				vy = Math.min(Math.max(vy, -0.7), 0.7);				
				if ( painFrames > 0 )
					id = baseID + 2;
				
				if ( reloadTime == 0 && Math.random() < 0.1 ){
					Game.singleton.enemyShoot( this );
					reloadTime += 30;
				}

			case pentagon:
				if ( reloadTime == 0 && Math.random() < 0.1 ){
					Game.singleton.spawnEnemy( circle, x, y );
					reloadTime = 30;
				}
				id = ( painFrames > 0 ) ? baseID + 1 : baseID;

			case hexagon:
				if ( reloadTime == 0 ){

					if ( Math.random() < 0.75 && Game.singleton.enemies.length > 4 ){
						Game.singleton.enemyShoot( this );
						reloadTime = 30 + Math.floor( Math.random() * 30 );
					} else {
						Game.singleton.spawnEnemy( triangle, x, y );
						reloadTime = 240 + Math.floor( Math.random() * 30 );
					}
				}
				id = ( painFrames > 0 ) ? baseID + 1 : baseID;

			case octagon:
				if ( reloadTime == 0 ){
	
					switch( sequence ){
						default: 
							sequence = 0;
						case 0:
							Game.singleton.spawnEnemy( circle, x, y );
							reloadTime += 120;
						case 1:
							Game.singleton.spawnEnemy( triangle, x, y );
							reloadTime += 180;
						case 2:
							Game.singleton.spawnEnemy( square, x, y );
							reloadTime += 240;

					}
					++sequence;
				}
				id = ( painFrames > 0 ) ? baseID + 1 : baseID;

		}

		if ( painFrames > 0 )
			--painFrames;

		if ( reloadTime > 0 )
			--reloadTime;

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
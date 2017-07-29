package;

import openfl.display.Sprite;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.display.Tile;
import openfl.display.Tileset;
import openfl.display.Tilemap;
import openfl.geom.Rectangle;

class Game extends Sprite {
	
	var spriteIndices : Map< SpriteType, Int >;
	var gameview : Tilemap;
	var tileset : Tileset;

	var roomTiles : Array<Tile>;

	public function new(){

		super();
		setupGUI();
		setupGameview();
		setRoom( true, true, true, true );

	}

	function setupGUI(){

		var guiBG = new Bitmap( Assets.getBitmapData("assets/background.png") );
		addChild( guiBG );

	}

	//Configure a room
	function setRoom( entranceUp : Bool, entranceRight : Bool, entranceDown : Bool, entranceLeft : Bool ){

		if ( roomTiles == null )
			roomTiles = new Array<Tile>();

		while ( roomTiles.length > 0 )
			gameview.removeTile( roomTiles.pop() );

		//Border
		//Top and bottom
		for ( i in 0...16 ){
			gameview.addTile( new Tile( spriteIndices.get( tileSetA ), i * 16, 0 ) );
			gameview.addTile( new Tile( spriteIndices.get( tileSetA ), i * 16, 10 * 16 ) );
		}
		//Left and right
		for ( i in 1...10 ){
			gameview.addTile( new Tile( spriteIndices.get( tileSetA ), 0, i * 16 ) );
			gameview.addTile( new Tile( spriteIndices.get( tileSetA ), 15*16, i * 16 ) );	
		}

	}

	/* create the gameview and define all the sprites it will use */
	function setupGameview(){

		spriteIndices = new Map<Game.SpriteType, Int>();
		//Background tiles
		//Set A
		spriteIndices.set( tileSetA, 0 );
		for ( i in 0...16 )
			defineSprite( i * 16, 0, 16, 16 );
		//Set B
		spriteIndices.set( tileSetB, 16 );
		for ( i in 0...16 )
			defineSprite( i * 16, 16, 16, 16 );
		//Set C
		spriteIndices.set( tileSetC, 32 );
		for ( i in 0...16 )
			defineSprite( i * 16, 32, 16, 16 );

		//Doors
		//H-door left
		defineSprite( 192, 48, 18, 16, door_h_l );
		//H-door right
		defineSprite( 192, 64, 18, 16, door_h_r );
		//V-door up
		defineSprite( 224, 48, 16, 18, door_v_u );
		//V-door down
		defineSprite( 240, 48, 16, 18, door_v_d );

		//Level exit
		defineSprite( 0, 48, 48, 48, exit );
		for ( i in 1...4 )
			tileset.addRect( new Rectangle( i * 48, 48, 48, 48 ) );

		//Enemies
		//Circle
		defineSprite( 176, 176, 16, 16, enemy_circle_l );
		defineSprite( 176, 192, 16, 16, enemy_circle_l );
		defineSprite( 192, 208, 16, 16, enemy_circle_damage );
		//Triangle
		defineSprite( 0, 96, 32, 32, enemy_triangle_l );
		defineSprite( 32, 96, 32, 32, enemy_triangle_l );
		defineSprite( 64, 96, 32, 32, enemy_triangle_damage );
		//Square
		defineSprite( 96, 96, 32, 32, enemy_square_l );
		defineSprite( 128, 96, 32, 32, enemy_square_l );
		defineSprite( 160, 96, 32, 32, enemy_square_damage );
		//Pentagon
		defineSprite( 0, 128, 48, 48, enemy_pentagon );
		defineSprite( 48, 128, 48, 48, enemy_pentagon_damage );
		//Hexagon
		defineSprite( 96, 128, 48, 48, enemy_hexagon );
		defineSprite( 144, 128, 48, 48, enemy_hexagon_damage );
		//Octagon
		defineSprite( 192, 80, 64, 64, enemy_hexagon );
		defineSprite( 192, 144, 64, 64, enemy_hexagon_damage );

		//Pickups
		defineSprite( 0, 176, 16, 16, pickup_power_a );
		defineSprite( 16, 176, 32, 32, pickup_power_b );
		defineSprite( 48, 176, 32, 32, pickup_weapon_a );
		defineSprite( 80, 176, 32, 32, pickup_weapon_b );
		defineSprite( 112, 176, 32, 32, pickup_weapon_c );
		defineSprite( 144, 176, 32, 32, pickup_weapon_d );

		//Bullets
		defineSprite( 0, 192, 16, 32, bullet_player_a );
		defineSprite( 16, 192, 16, 16, bullet_player_b );
		defineSprite( 32, 208, 16, 16, bullet_enemy_a );
		defineSprite( 48, 208, 16, 16, bullet_enemy_b );
		//Beams
		defineSprite( 16, 208, 16, 3, beam_player );
		defineSprite( 16, 211, 16, 3, beam_enemy );

		//Warnings
		defineSprite( 64, 208, 4, 16, warning_a );
		defineSprite( 68, 208, 4, 16, warning_b );

		//Player
		defineSprite( 0, 224, 32, 32, player_a );
		defineSprite( 32, 224, 32, 32, player_b );
		defineSprite( 64, 224, 32, 32, player_damage );

		//Explosions
		defineSprite( 96, 208, 48, 48, explosion_large );
		defineSprite( 144, 208, 48, 48 );
		defineSprite( 192, 224, 32, 32, explosion_medium );
		defineSprite( 224, 224, 48, 48 );
		defineSprite( 192, 208, 16, 16, explosion_small );
		defineSprite( 208, 208, 48, 48 );
		defineSprite( 224, 208, 8, 8, explosion_tiny );
		defineSprite( 232, 208, 48, 48 );

		//Particles
		defineSprite( 80, 208, 8, 8, particle_portal );
		defineSprite( 88, 208, 8, 8 );
		defineSprite( 80, 216, 8, 8 );
		defineSprite( 88, 216, 8, 8 );
		defineSprite( 240, 208, 16, 16, particle_smoke_large );
		defineSprite( 224, 216, 8, 8, particle_smoke_medium );
		defineSprite( 232, 216, 4, 4, particle_smoke_small );

		gameview = new Tilemap( 256, 176, tileset, false );
		addChild( gameview );
	}

	function defineSprite( x : Int, y : Int, width: Int, height : Int, ?spriteType : SpriteType ){

		if ( spriteIndices == null )
			spriteIndices = new Map<SpriteType, Int>();

		if ( tileset == null )
			tileset = new Tileset( Assets.getBitmapData( "assets/spritesheet.png" ) );

		var rect = new Rectangle( x, y, width, height );
		var index = tileset.addRect( rect );
		if ( spriteType != null )
			spriteIndices.set( spriteType, index );

	}

}

enum SpriteType {
	tileSetA;
	tileSetB;
	tileSetC;
	door_h_l;
	door_h_r;
	door_v_u;
	door_v_d;
	exit;
	enemy_circle_l;
	enemy_circle_r;
	enemy_circle_damage;
	enemy_triangle_l;
	enemy_triangle_r;
	enemy_triangle_damage;
	enemy_square_l;
	enemy_square_r;
	enemy_square_damage;
	enemy_pentagon;
	enemy_pentagon_damage;
	enemy_hexagon;
	enemy_hexagon_damage;
	enemy_octagon;
	enemy_octagon_damage;
	pickup_power_a;
	pickup_power_b;
	pickup_weapon_a;
	pickup_weapon_b;
	pickup_weapon_c;
	pickup_weapon_d;
	bullet_player_a;
	bullet_player_b;
	bullet_enemy_a;
	bullet_enemy_b;
	beam_player;
	beam_enemy;
	warning_a;
	warning_b;
	player_a;
	player_b;
	player_damage;
	explosion_large;
	explosion_medium;
	explosion_small;
	explosion_tiny;
	particle_portal;
	particle_smoke_large;
	particle_smoke_medium;
	particle_smoke_small;
}
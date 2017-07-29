package;

import openfl.display.Sprite;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.display.Tile;
import openfl.display.Tileset;
import openfl.display.Tilemap;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.ui.Keyboard;

class Game extends Sprite {

	var time : Float;
	var timeStep : Float;
	
	var spriteIndices : Map< SpriteType, Int >;
	var gameview : Tilemap;
	var tileset : Tileset;

	var roomTiles : Array<Tile>;
	var player : Sprite;
	var playerTexture : Bitmap;
	var playerHead : Sprite;
	var playerMask : Bitmap;
	var input : Map<InputType, Int>;
	var cursor : Bitmap;

	var testBitmap : Bitmap;
	var testMask : Sprite;

	var vx : Float = 0;
	var vy : Float = 0;

	public function new(){

		super();

		time = 0;
		timeStep = 1/60;

		setupInput();
		setupPlayer();
		setupGUI();
		setupGameview();
		setRoom( false, false, false, false );
		setupCursor();

		addEventListener( Event.ADDED_TO_STAGE, onAddedToStage );

	}

	function tick(){

		openfl.ui.Mouse.hide();

		cursor.x = mouseX - 8;
		cursor.y = mouseY - 8;

		time += timeStep;

		tickPlayer();
		tickInput();
		// testMask.cacheAsBitmap = true;
		
	}

	function tickPlayer(){

		var acceleration = 0.25;

		if ( getInputActive( up ) )
			vy = Math.max( -2, vy - acceleration );
		if ( getInputActive( down ) )
			vy = Math.min( 2, vy + acceleration );
		if ( !getInputActive(up) && !getInputActive(down) )
			vy = vy * 0.9;
		if ( getInputActive( left ) )
			vx = Math.max( -2, vx - acceleration );
		if ( getInputActive( right ) )
			vx = Math.min( 2, vx + acceleration );
		if ( !getInputActive(left) && !getInputActive(right) )
			vx = vx * 0.9;
		//Move Player
		player.x += vx;
		player.y += vy;
		var rollSpeed = 1.5;
		playerTexture.x += rollSpeed * vx;
		playerTexture.y += rollSpeed * vy;
		
		while ( playerTexture.x < -96 )
			playerTexture.x += 64;
		while ( playerTexture.x > -32 )
			playerTexture.x -= 64;
		while ( playerTexture.y < -96 )
			playerTexture.y += 64;
		while ( playerTexture.y > -32 )
			playerTexture.y -= 64;
		
		playerHead.rotation = Math.atan2( mouseY - player.y, mouseX - player.x ) * 180 / Math.PI + 90;

	}

	function tickInput(){

		for ( inputType in input.keys() ){
			var val : Int = input.get( inputType );
			if ( val != 0 )
				input.set( inputType, val + 1 );
		}

	}

	function getInputActivating( inputType : Game.InputType ){
		return input.get( inputType ) == 1;
	}

	function getInputActive( inputType : Game.InputType ){
		return input.get( inputType ) > 0;
	}

	function getInputDeactivating( inputType : Game.InputType ){
		return input.get( inputType ) < 0;
	}

	function setupInput(){

		input = new Map<InputType, Int>();
		input.set( quit, 0 );
		input.set( up, 0 );
		input.set( right, 0 );
		input.set( down, 0 );
		input.set( left, 0 );
		input.set( shoot, 0 );

	}

	function setupPlayer(){

		if ( player != null ){
			removeChild( player );
		}
		player = new Sprite();
		playerTexture = new Bitmap( Assets.getBitmapData( "assets/playertexture.png" ) );
		playerTexture.x = -playerTexture.width/2;
		playerTexture.y = -playerTexture.height/2;
		player.addChild( playerTexture );

		playerMask = new Bitmap( Assets.getBitmapData("assets/playermask.png" ) );
		playerMask.x = -playerMask.width/2;
		playerMask.y = -playerMask.height/2;
		player.addChild( playerMask );
		playerHead = new Sprite();
		var headBMP = new Bitmap( Assets.getBitmapData( "assets/playerhead.png") );
		playerHead.addChild( headBMP );
		headBMP.x = -playerHead.width/2;
		headBMP.y = -18;
		player.addChild( playerHead );
		player.x = 128;
		player.y = 128;
		addChild( player );
	}

	function setupCursor(){

		if ( cursor != null )
			removeChild( cursor );
		cursor = new Bitmap( Assets.getBitmapData( "assets/cursor.png" ) );
		addChild( cursor );

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
		//Top
		for ( i in 0...7)
			gameview.addTile( new Tile( spriteIndices.get( tileSetA ), i * 16, 0 ) );
		if ( entranceUp ){

		} else { //No top door, fill in border
			gameview.addTile( new Tile( spriteIndices.get( tileSetB ), 7 * 16, 0 ) );
			gameview.addTile( new Tile( spriteIndices.get( tileSetB ), 8 * 16, 0 ) );	
		}
		for ( i in 9...16)
			gameview.addTile( new Tile( spriteIndices.get( tileSetA ), i * 16, 0 ) );
		//Bottom
		for ( i in 0...7)
			gameview.addTile( new Tile( spriteIndices.get( tileSetA ), i * 16, 10*16 ) );
		if ( entranceUp ){

		} else { //No top door, fill in border
			gameview.addTile( new Tile( spriteIndices.get( tileSetB ), 7 * 16, 10*16 ) );
			gameview.addTile( new Tile( spriteIndices.get( tileSetB ), 8 * 16, 10*16 ) );	
		}
		for ( i in 9...16)
			gameview.addTile( new Tile( spriteIndices.get( tileSetA ), i * 16, 10*16 ) );
		
		//Left
		for ( i in 1...5 )
			gameview.addTile( new Tile( spriteIndices.get( tileSetA ), 0, i*16 ) );
		if ( entranceLeft ){

		} else {
			gameview.addTile( new Tile( spriteIndices.get( tileSetB ), 0, 5*16 ) );
			gameview.addTile( new Tile( spriteIndices.get( tileSetB ), 0, 6*16 ) );
		}
		for ( i in 7...10 )
			gameview.addTile( new Tile( spriteIndices.get( tileSetA ), 0, i*16 ) );
		
		//Right
		for ( i in 1...5 )
			gameview.addTile( new Tile( spriteIndices.get( tileSetA ), 15*16, i*16 ) );
		if ( entranceLeft ){

		} else {
			gameview.addTile( new Tile( spriteIndices.get( tileSetB ), 15*16, 5*16 ) );
			gameview.addTile( new Tile( spriteIndices.get( tileSetB ), 15*16, 6*16 ) );
		}
		for ( i in 7...10 )
			gameview.addTile( new Tile( spriteIndices.get( tileSetA ), 15*16, i*16 ) );
		

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

	/* Test if a circle intersects a square tile
		Create two circles, one within the tile touching each edge, and one that touches each corner of the square
		If the test circle intersects the inner circle, it is a definite collision
		If the test circle intersects the outer circle, test to see if the closest point of the test circle is
		within the tile bounding box
	*/
	function intersectCircleTile( circleX : Float, circleY : Float, circleR : Float, tileX : Float, tileY : Float, tileSize : Float ){

		var tileInnerCircleRadius = 8;
		var tileOuterCircleRadius = 11;

		var tileCentreX = tileX + 8;
		var tileCentreY = tileY + 8;

		var circleCentre = new Point ( circleX, circleY );
		var tileCentre = new Point( tileCentreX, tileCentreY );

		var d = Point.distance( circleCentre, tileCentre );

		//Circle doesn't interset tile outer circle, no collision possible
		if ( d > circleR + tileOuterCircleRadius )
			return false;

		//Circle intersects tile inner circle
		if ( d < circleR + tileInnerCircleRadius )
			return true;

		var testVector = tileCentre.subtract( circleCentre );
		testVector.normalize( circleR );
		var testPoint = circleCentre.add( testVector );
		return ( testPoint.x < tileX + tileSize && testPoint.y < tileY + tileSize && testPoint.x > tileX && testPoint.y > tileY );
	}

	function onEnterFrame( e : Event ){

		tick();

	}

	function onMouseDown( e : MouseEvent ){
		input.set( shoot, 1 );
	}

	function onMouseUp( e : MouseEvent ){
		input.set( shoot, -1 );
	}

	function onMouseRightDown( e : MouseEvent ){
		input.set( shoot, 1 );
	}

	function onMouseRightUp( e : MouseEvent ){
		input.set( shoot, -1 );
	}

	function onKeyDown( e : KeyboardEvent ){
		switch( e.keyCode ){
			default:
				return;
			case Keyboard.W:
				input.set( up, 1 );
			case Keyboard.A:
				input.set( left, 1 );
			case Keyboard.S:
				input.set( down, 1 );
			case Keyboard.D:
				input.set( right, 1 );
			case Keyboard.UP:
				input.set( up, 1 );
			case Keyboard.LEFT:
				input.set( left, 1 );
			case Keyboard.DOWN:
				input.set( down, 1 );
			case Keyboard.RIGHT:
				input.set( right, 1 );
			case Keyboard.ESCAPE:
				input.set( quit, 1 );
				Sys.exit(0);
		}
	}

	function onKeyUp( e : KeyboardEvent ){
		switch( e.keyCode ){
			default:
				return;
			case Keyboard.W:
				input.set( up, -1 );
			case Keyboard.A:
				input.set( left, -1 );
			case Keyboard.S:
				input.set( down, -1 );
			case Keyboard.D:
				input.set( right, -1 );
			case Keyboard.UP:
				input.set( up, -1 );
			case Keyboard.LEFT:
				input.set( left, -1 );
			case Keyboard.DOWN:
				input.set( down, -1 );
			case Keyboard.RIGHT:
				input.set( right, -1 );
			case Keyboard.ESCAPE:
				input.set( quit, -1 );
		}
	}
	function onAddedToStage( e : Event ){

		addEventListener( Event.ENTER_FRAME, onEnterFrame );
		addEventListener( MouseEvent.MOUSE_DOWN, onMouseDown );
		addEventListener( MouseEvent.MOUSE_UP, onMouseUp );
		addEventListener( MouseEvent.RIGHT_MOUSE_DOWN, onMouseRightDown );
		addEventListener( MouseEvent.RIGHT_MOUSE_UP, onMouseRightUp );
		stage.addEventListener( KeyboardEvent.KEY_DOWN, onKeyDown );
		stage.addEventListener( KeyboardEvent.KEY_UP, onKeyUp );

	}

	private function applyMask (bitmap:Bitmap, mask:openfl.display.DisplayObject):Void {
		
		#if flash
		
		bitmap.mask = mask;
		
		#else
		
		var bitmapDataMask = new BitmapData (bitmap.bitmapData.width, bitmap.bitmapData.height, true, 0);
		bitmapDataMask.draw (mask);
		
		var shader = new openfl.display.Shader ();
		shader.glFragmentSource = 
			
			"varying float vAlpha;
			varying vec2 vTexCoord;
			uniform sampler2D uImage0;
			uniform sampler2D uImage1;
			
			void main(void) {
				
				vec4 color = texture2D (uImage0, vTexCoord);
				float mask = texture2D (uImage1, vTexCoord).a;
				
				if (color.a == 0.0 || mask == 0.0) {
					
					gl_FragColor = vec4 (0.0, 0.0, 0.0, 0.0);
					
				} else {
					
					gl_FragColor = vec4 (color.rgb / color.a, mask * color.a * vAlpha);
					
				}
				
			}";
		
		shader.data.uImage1.input = bitmapDataMask;
		
		bitmap.filters = [ new openfl.filters.ShaderFilter (shader) ];
		
		#end
		
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

enum InputType {

	quit;
	left;
	right;
	up;
	down;
	shoot;

}
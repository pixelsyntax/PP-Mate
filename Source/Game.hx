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

	var minimap : Tilemap;
	var minimapData : Array<Int>;
	var minimapHiddenData : Array<Int>;
	var minimapDoorData : Array<Array<Bool>>;

	var worldContainer : Sprite;

	var roomTiles : Array<Tile>;
	var backgroundTiles : Array<Tile>;
	var doorTiles : Array<Tile>;

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
	var collisionVector : Point;

	var shader : openfl.display.Shader;
	var scrollPos : Point;

	var doorProgress : Float;
	var roomComplete : Bool;
	var screenShake : Float;
	var shakeOffset : Point;

	var currentRoomIndex : Int;
	var roomData : Array<Array<Int>>;
	var roomsComplete : Array<Bool>;
	var roomBackgrounds : Array<Array<Int>>;
	var roomLayoutLibrary : Array<Array<Int>>;
	var roomBackgroundsLibrary : Array<Array<Int>>;

	public function new(){

		super();

		time = 0;
		timeStep = 1/60;
		collisionVector = new Point(0,0);
		worldContainer = new Sprite();
		addChild( worldContainer );
		setupRoomDataLibrary();
		setupGameview();
		setupDoors();
		generateMap();
		setupInput();		
		setupPlayer();
		setupCursor();
		setupGUI();

		setRoom( currentRoomIndex );
		addNeighbouringRoomsToMinimap();

		addEventListener( Event.ADDED_TO_STAGE, onAddedToStage );
	}

	function tick(){

		openfl.ui.Mouse.hide();

		cursor.x = mouseX - 8;
		cursor.y = mouseY - 8;

		time += timeStep;

		tickDoors();
		tickPlayer();
		tickInput();
		
		shader.data.uScrollPos.value = [scrollPos.x, scrollPos.y];
		
		screenShake = Math.min(2, Math.max( 0, screenShake - 0.05 ));
		shakeOffset.x = 5 * Math.random() * screenShake - screenShake/2;
		shakeOffset.y = 5 * Math.random() * screenShake - screenShake/2;
		worldContainer.x = shakeOffset.x;
		worldContainer.y = shakeOffset.y;

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
		var nx = vx;
		var ny = vy;
		while ( circleCollidesWithMap( player.x, player.y, 13 ) ){
			player.x -= collisionVector.x / 13;
			player.y -= collisionVector.y / 13;
		}
		if( circleCollidesWithMap( player.x + vx, player.y, 12 ) ){
			vx = 0;
		}
		if( circleCollidesWithMap( player.x, player.y + vy, 12 ) ){
			vy = 0;
			
		}
		player.x += vx;
		player.y += vy;
		var rollSpeed = 0.01;
		scrollPos.x -= rollSpeed * vx;
		scrollPos.y -= rollSpeed * vy;
		
		while ( scrollPos.x < 0.25 )
			scrollPos.x += 0.5;
		while ( scrollPos.x > 0.75 )
			scrollPos.x -= 0.5;
		while ( scrollPos.y < 0.25 )
			scrollPos.y += 0.5;
		while ( scrollPos.y > 0.75 )
			scrollPos.y -= 0.5;
		
		playerHead.rotation = Math.atan2( mouseY - player.y, mouseX - player.x ) * 180 / Math.PI + 90;

		if ( getInputActivating(InputType.shoot) ){
			completeRoom();
		}

		if ( roomComplete ){

			if ( player.y < 0 )
				travelThroughDoor( 0 )
			else if ( player.x > gameview.width )
				travelThroughDoor( 1 );
			else if ( player.y > gameview.height )
				travelThroughDoor( 2 );
			else if ( player.x < 0 )
				travelThroughDoor( 3 );

		}

	}

	function tickDoors(){

		if ( roomComplete && doorProgress < 1 ){
			doorProgress = Math.min( 1, doorProgress + 0.02 );
			//TODO rumble sound
			//TODO door rumble screenshake
			screenShake = 0.2;
		}

		if ( !roomComplete && doorProgress > 0 ){
			doorProgress = Math.max( 0, doorProgress - 0.05 );
			if ( doorProgress == 0 ){
				//TODO slam sound
				screenShake = 1;
			}
		}

		var offset = doorProgress * 18;
		doorTiles[0].x = 7 * 16 - offset;
		doorTiles[1].x = 8 * 16 -2 + offset;
		doorTiles[2].x = 7 * 16 - offset;
		doorTiles[3].x = 8 * 16 -2 + offset;
		doorTiles[4].y = 5 * 16 - offset;
		doorTiles[5].y = 6 * 16 -2 + offset;
		doorTiles[6].y = 5 * 16 - offset;
		doorTiles[7].y = 6 * 16 -2 + offset;
			
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
		scrollPos = new Point();

		player = new Sprite();
		playerTexture = new Bitmap( Assets.getBitmapData( "assets/playertexture.png" ) );
		playerTexture.x = -12;
		playerTexture.y = -12;
		player.addChild( playerTexture );

		playerMask = new Bitmap( Assets.getBitmapData( "assets/playermask.png" ) );
		// playerMask.graphics.beginFill(0xFFFFFF);
		// player.addChild( playerMask );
		applyMask( playerTexture, playerMask );

		playerHead = new Sprite();
		var headBMP = new Bitmap( Assets.getBitmapData( "assets/playerhead.png") );
		playerHead.addChild( headBMP );
		headBMP.x = -playerHead.width/2;
		headBMP.y = -18;
		player.addChild( playerHead );
		player.x = 128;
		player.y = 128;
		worldContainer.addChild( player );
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

		var minimapTileset = new Tileset( Assets.getBitmapData("assets/gui.png") );
		minimapTileset.addRect( new Rectangle( 4, 36, 12, 12 ) ); //Current room indicator 0
		minimapTileset.addRect( new Rectangle( 24, 32, 8, 8 ) ); //unexplored room 1
		minimapTileset.addRect( new Rectangle( 16, 32, 8, 8 ) ); //explored room 2
		minimapTileset.addRect( new Rectangle( 64, 32, 12, 12 ) ); //unexplored boss room 3
		minimapTileset.addRect( new Rectangle( 24, 40, 8, 8 ) ); //unexplored exit 4
		minimapTileset.addRect( new Rectangle( 16, 40, 12, 12 ) ); //explored exit 5
		minimapTileset.addRect( new Rectangle( 0, 32, 4, 2 ) ); //door h 6
		minimapTileset.addRect( new Rectangle( 0, 32, 2, 4 ) ); //door v 7

		minimap = new Tilemap( 60, 60, minimapTileset, false );
		addChild( minimap );
		minimap.x = 194;
		minimap.y = 178;

	}

	function setupDoors(){

		doorProgress = 1;

		if ( doorTiles == null )
			doorTiles = new Array<Tile>();

		//Doors
		//Top and bottom
		doorTiles.push( gameview.addTile( new Tile( spriteIndices.get( door_h_l ), 7 * 16, 0 ) ) );
		doorTiles.push( gameview.addTile( new Tile( spriteIndices.get( door_h_r ), 8 * 16 - 2, 0 ) ) );
		doorTiles.push( gameview.addTile( new Tile( spriteIndices.get( door_h_l ), 7 * 16, 10*16 ) ) );
		doorTiles.push( gameview.addTile( new Tile( spriteIndices.get( door_h_r ), 8 * 16 - 2, 10*16 ) ) );
		//Left and right
		doorTiles.push( gameview.addTile( new Tile( spriteIndices.get( door_v_u ), 0, 5*16 ) ) );
		doorTiles.push( gameview.addTile( new Tile( spriteIndices.get( door_v_d ), 0, 6*16-2 ) ) );
		doorTiles.push( gameview.addTile( new Tile( spriteIndices.get( door_v_u ), 15 * 16, 5*16 ) ) );
		doorTiles.push( gameview.addTile( new Tile( spriteIndices.get( door_v_d ), 15 * 16, 6*16-2 ) ) );

	}

	function completeRoom(){

		roomComplete = true;
		roomsComplete[currentRoomIndex] = true;

	}

	//Configure a room
	function setRoom( roomIndex : Int ){

		var room = roomData[roomIndex];
		roomComplete = roomsComplete[roomIndex];

		if ( roomTiles == null )
			roomTiles = new Array<Tile>();

		while ( roomTiles.length > 0 )
			gameview.removeTile( roomTiles.pop() );

		if ( backgroundTiles == null )
			backgroundTiles = new Array<Tile>();

		while ( backgroundTiles.length > 0 )
			gameview.removeTile( backgroundTiles.pop() );

		for ( y in 0...11 ){
			for ( x in 0...16 ){
				var i = x + y * 16;
				var v = room[i];
				if ( v > 0 ){
					var tile = new Tile(v-1, x * 16, y * 16);
					roomTiles.push( gameview.addTile( tile ) );
				}
			}
		}

		addNeighbouringRoomsToMinimap();

	}

	/* create the gameview and define all the sprites it will use */
	function setupGameview(){

		screenShake = 0;
		shakeOffset = new Point(0,0);
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
		worldContainer.addChild( gameview );
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

	function circleCollidesWithMap( circleX : Float, circleY : Float, circleR : Float ){

		for ( tile in doorTiles ){
			if ( intersectCircleTile( circleX, circleY, circleR, tile.x, tile.y ) )
				return true;
		}

		for ( tile in roomTiles ){
			if ( intersectCircleTile( circleX, circleY, circleR, tile.x, tile.y ) )
				return true;
		}
		return false;

	}

	/* Test if a circle intersects a square tile
		Create two circles, one within the tile touching each edge, and one that touches each corner of the square
		If the test circle intersects the inner circle, it is a definite collision
		If the test circle intersects the outer circle, test to see if the closest point of the test circle is
		within the tile bounding box
	*/
	function intersectCircleTile( circleX : Float, circleY : Float, circleR : Float, tileX : Float, tileY : Float ){

		var tileInnerCircleRadius = 8;
		var tileOuterCircleRadius = 16;

		var tileCentreX = tileX + 8;
		var tileCentreY = tileY + 8;

		var circleCentre = new Point ( circleX, circleY );
		var tileCentre = new Point( tileCentreX, tileCentreY );

		var d = Point.distance( circleCentre, tileCentre );

		//Circle doesn't interset tile outer circle, no collision possible
		if ( d > circleR + tileOuterCircleRadius )
			return false;

		var testVector = tileCentre.subtract( circleCentre );
		testVector.normalize( circleR );

		//Circle intersects tile inner circle
		if ( d < circleR + tileInnerCircleRadius ){
			collisionVector = testVector;
			return true;
		}

		var testPoint = circleCentre.add( testVector );
		if ( testPoint.x < tileX + 16 && testPoint.y < tileY + 16 && testPoint.x > tileX && testPoint.y > tileY ){
			collisionVector = testVector;
			return true;
		}

		return false;
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

	function travelThroughDoor( direction : Int ){

		switch( direction ){
			case 0: //up
				currentRoomIndex -= 5;
				player.y += gameview.height -24;
			case 1: //right
				currentRoomIndex += 1;
				player.x -= gameview.width - 24;
			case 2: //down
				currentRoomIndex += 5;
				player.y -= gameview.height -24 ;
			case 3: //left
				currentRoomIndex -= 1;
				player.x += gameview.width -24 ;
		}

		setRoom( currentRoomIndex );

	}

	function addNeighbouringRoomsToMinimap(){

		if ( minimapData[currentRoomIndex] % 2 == 1 )
			minimapData[currentRoomIndex] += 1;
		var room = roomData[currentRoomIndex];
		var doorUp = room[7] == 0;
		var doorRight = room[15 + 5*16] == 0;
		var doorDown = room[7 + 10*16] == 0;
		var doorLeft = room[5*16] == 0;
		minimapDoorData[currentRoomIndex] = [doorUp, doorRight, doorDown, doorLeft];
		if ( doorUp && minimapData[currentRoomIndex-5] == 0 )
			minimapData[currentRoomIndex-5] = minimapHiddenData[currentRoomIndex-5];
		if ( doorRight && minimapData[currentRoomIndex+1] == 0 )
			minimapData[currentRoomIndex+1] = minimapHiddenData[currentRoomIndex+1];
		if ( doorDown && minimapData[currentRoomIndex+5] == 0 )
			minimapData[currentRoomIndex+5] = minimapHiddenData[currentRoomIndex+5];
		if ( doorLeft && minimapData[currentRoomIndex-1] == 0 )
			minimapData[currentRoomIndex-1] = minimapHiddenData[currentRoomIndex-1];


		drawMinimap();

	}

	function drawMinimap(){

		var mapTileSize = 12;

		while( minimap.numTiles > 0 )
			minimap.removeTileAt(0);

		for ( y in 0...5 ){
			for ( x in 0...5 ){
				var i = x + y * 5;
				if ( minimapData[i] > 0 ){
					var dx = x * mapTileSize + 2;
					var dy = y * mapTileSize + 2;

					var doorData = minimapDoorData[i];
					if ( doorData[0] )
						minimap.addTile( new Tile( 7, dx + 3, dy -4 ) );
					if ( doorData[1] )
						minimap.addTile( new Tile( 6, dx + mapTileSize - 4, dy +3 ) );
					if ( doorData[2] )
						minimap.addTile( new Tile( 7, dx + 3, dy + mapTileSize - 4) );
					if ( doorData[3] )
						minimap.addTile( new Tile( 6, dx - 4, dy + 3 ) );

					//room
					var tile = new Tile( minimapData[i], dx, dy );
					minimap.addTile( tile );
				}
			}
		}

		var px = (currentRoomIndex % 5) * mapTileSize;
		var py = Math.floor(currentRoomIndex / 5) * mapTileSize;
		var tile = new Tile( 0, px, py );
		minimap.addTile( tile );

	}

	function generateMap(){

		var mapWidth : Int = 5;
		var mapHeight : Int = 5;
		currentRoomIndex = 12;

		roomData = new Array<Array<Int>>();
		roomsComplete = new Array<Bool>();
		minimapData = new Array<Int>();
		minimapHiddenData = new Array<Int>();
		minimapDoorData = new Array<Array<Bool>>();
		for ( i in 0...mapWidth*mapHeight ){
			minimapData.push(0);
			minimapDoorData.push( [false, false, false, false] );
			roomsComplete.push( false );
		}

		for ( y in 0...mapHeight ){

			var doorUp = y != 0;
			var doorDown = y != mapHeight -1;

			for ( x in 0...mapWidth ){

				var mapIndex = x + y * mapWidth;
				var doorRight = x != mapWidth - 1;				
				var doorLeft = x != 0;
				roomData.push(generateNormalRoom( doorUp, doorRight, doorDown, doorLeft ));
				minimapHiddenData.push( 1 );

			}
		}		

		minimapData[currentRoomIndex] = minimapHiddenData[currentRoomIndex];
	}

	function generateNormalRoom( doorUp : Bool, doorRight : Bool, doorDown : Bool, doorLeft : Bool ) : Array<Int> {

		if ( roomLayoutLibrary == null )
			setupRoomDataLibrary();


		var index : Int = 0;
		//Normal room 0-5
		index = Math.floor( Math.random() * 5 );

		if ( !doorUp && doorRight && doorDown && doorLeft )
			index = 5;
		if ( doorUp && !doorRight && doorDown && doorLeft )
			index = 6;
		if ( doorUp && doorRight && !doorDown && doorLeft )
			index = 7;
		if ( doorUp && doorRight && doorDown && !doorLeft )
			index = 8;
		var room = roomLayoutLibrary[index].copy();
		if ( !doorUp ){
			room[7] = 1;
			room[8] = 1;
		}
		if ( !doorRight ){
			room[15 + 5*16] = 1;
			room[15 + 6*16] = 1;
		}
		if ( !doorDown ){
			room[7+10*16] = 1;
			room[8+10*16] = 1;
		}
		if ( !doorLeft ){
			room[5*16] = 1;
			room[6*16] = 1;
		}
		for ( i in 0...room.length ){
			var v = room[i];
			if ( v == 1 ) //Pick a random tile 
				room[i] += Math.floor( Math.random() * 8 );
		}

		return room;
	}

	function generateBossRoom( doorUp : Bool, doorRight : Bool, doorDown : Bool, doorLeft : Bool ){

		var room = roomLayoutLibrary[0].copy();
		if ( !doorUp ){
			room[7] = 1;
			room[8] = 1;
		}
		if ( !doorRight ){
			room[15 + 5*16] = 1;
			room[15 + 6*16] = 1;
		}
		if ( !doorDown ){
			room[7+10*16] = 1;
			room[8+10*16] = 1;
		}
		if ( !doorLeft ){
			room[5*16] = 1;
			room[6*16] = 1;
		}
		for ( i in 0...room.length ){
			var v = room[i];
			if ( v == 1 ) //Pick a random tile 
				room[i] += Math.floor( Math.random() * 8 );
		}

	}

	function setupRoomDataLibrary(){

		roomLayoutLibrary = new Array<Array<Int>>();
		//0 Basic room
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);
		
		//1, 2, 3, 4 Centre Obstacle rooms
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);		
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
			 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1,
			 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1,
			 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0,
			 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1,
			 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
			 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
			 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);

		// 5 Blocked top
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
			 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
			 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
			 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);

		// 6 Blocked right
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);
		// 7 Blocked down
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
			 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
			 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
			 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
			]);	
		// 8 Blocked left
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);

		roomBackgroundsLibrary = new Array<Array<Int>>();
		roomBackgroundsLibrary.push([
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4, 3, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
		]);

	}



	private function applyMask (bitmap:Bitmap, mask:openfl.display.DisplayObject):Void {
		
		#if flash
		
		bitmap.mask = mask;
		
		#else
		
		var bitmapDataMask = new BitmapData (bitmap.bitmapData.width, bitmap.bitmapData.height, true, 0);
		bitmapDataMask.draw (mask);
		
		scrollPos = new Point( 0.5, 0.5 );
		shader = new openfl.display.Shader ();
		shader.glFragmentSource = 
			
			"varying float vAlpha;
			varying vec2 vTexCoord;
			uniform vec2 uScrollPos;
			uniform sampler2D uImage0;
			uniform sampler2D uImage1;
			
			void main(void) {
				
				vec4 color = texture2D (uImage0, vTexCoord + uScrollPos);
				float mask = texture2D (uImage1, vTexCoord).a;
				
				if (color.a == 0.0 || mask == 0.0) {
					
					gl_FragColor = vec4 (0.0, 0.0, 0.0, 0.0);
				
				} else if ( mask > 0.4 && mask < 0.6 ) {

					gl_FragColor = vec4 (0.89, 0.32, 0.0, 1.0 );

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

enum RoomType {

	entrance;
	normal;
	bonus;
	boss;
	exit;

}
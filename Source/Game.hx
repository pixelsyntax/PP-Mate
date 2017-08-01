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
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.media.SoundTransform;
import openfl.media.SoundMixer;

class Game extends Sprite {

	public static var singleton;
	public var isExpired : Bool;

	var time : Float;
	var timeStep : Float;
	
	public var spriteIndices : Map< SpriteType, Int >;
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

	public var player : Sprite;
	var playerTexture : Bitmap;
	var playerHead : Sprite;
	var playerMask : Bitmap;
	var playerPainBody : Bitmap;
	var playerPainHead : Bitmap;
	var playerWeapon : Game.PlayerWeapon;
	var input : Map<InputType, Int>;
	var cursor : Bitmap;

	var testBitmap : Bitmap;
	var testMask : Sprite;

	public var vx : Float = 0;
	public var vy : Float = 0;
	var collisionVector : Point;

	var shader : openfl.display.Shader;
	var scrollPos : Point;

	var doorProgress : Float;
	var roomComplete : Bool;
	var completeFrames : Int;
	var screenShake : Float;
	var shakeOffset : Point;

	var bossDefeated : Bool;
	var boss : Enemy;
	var currentRoomIndex : Int;
	var roomData : Array<Array<Int>>;
	var roomsComplete : Array<Bool>;
	var roomBackgrounds : Array<Array<Int>>;
	var roomLayoutLibrary : Array<Array<Int>>;
	var roomBackgroundsLibrary : Array<Array<Int>>;
	var mapLibrary : Array<Array<Int>>;

	var playerProjectiles : Array<Projectile>;
	var enemyProjectiles : Array<Projectile>;
	public var enemies : Array<Enemy>;

	var warnings : Array<Tile>;
	var warningFrames : Int;

	var animate : Bool;
	var alternate : Bool;

	var pickups : Array<Pickup>;
	var reloadTime : Int;
	var truePowerLevel : Float;
	var displayedPowerLevel : Float;
	var trueHealthLevel : Float;
	var displayedHealthLevel : Float;
	var invincibleFrames : Int;
	var powerBarGreen : Tile;
	var powerBarWhite : Tile;
	var healthBarGreen : Tile;
	var healthBarWhite : Tile;
	var gui : Tilemap;
	var guiWeaponIcon : Tile;
	var roomsEntered : Int;
	var mapsComplete : Int;
	var exit : Exit;
	var exitFrames : Int;

	var effects : Array<Effect>;

	var sounds : Map<Game.SoundType, Array<Sound>>;
	var soundTriggeredThisFrame : Bool;

	var clockDigits : Array<Tile>;
	var clockMinutes : Int;
	var clockSeconds : Int;
	var clockFrames : Int;
	var lostFrames : Int;
	var gameover : Bool;

	public function new(){

		singleton = this;
		isExpired = false;

		gameover = false;
		lostFrames = 0;

		super();

		animate = false;
		alternate = false;
		soundTriggeredThisFrame = false;

		time = 0;
		mapsComplete = 0;
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
		setupClock();
		setupSounds();
		setWeapon( weapon_none );

		setRoom( currentRoomIndex );
		addNeighbouringRoomsToMinimap();

		addEventListener( Event.ADDED_TO_STAGE, onAddedToStage );

		
	}

	function tick(){

		cursor.x = mouseX - 8;
		cursor.y = mouseY - 8;

		openfl.ui.Mouse.hide();
		animate = !animate;
		if ( animate )
			alternate = !alternate;

		if ( gameover ){
			++lostFrames;
			powerBarGreen.scaleX = 0;
			powerBarWhite.scaleX = 0;
			player.visible = false;
			for ( clockTile in clockDigits )
				clockTile.visible = alternate;

			if ( lostFrames > 90 && getInputActivating( InputType.shoot ) )
				isExpired = true;

			return;
		}

		updateClock();


		time += timeStep;

		tickDoors();
		tickPlayer();
		tickInput();
		tickEnemies();
		tickProjectiles();
		tickWarnings();
		tickGUI();
		tickPickups();
		tickExit();
		tickEffects();

		//Update rolly shader
		shader.data.uScrollPos.value = [scrollPos.x, scrollPos.y];
		
		//Screeeeenshaaake
		screenShake = Math.min(2, Math.max( 0, screenShake - 0.05 ));
		shakeOffset.x = 5 * Math.random() * screenShake - screenShake/2;
		shakeOffset.y = 5 * Math.random() * screenShake - screenShake/2;
		worldContainer.x = shakeOffset.x;
		worldContainer.y = shakeOffset.y;

		if ( warnings.length == 0 && enemies.length == 0 && !roomComplete && playerWeapon != weapon_none ){
			++completeFrames;
			if ( completeFrames > 30 )
				completeRoom();
		}

		//Only allow one sound to be triggered per frame to avoid super loudness but also emulate limited sound channels
		//or so im telling myself.
		soundTriggeredThisFrame = false;

	}

	function tickExit(){

		if ( exit == null )
			return;

		spawnEffect( Effect.EffectType.particle_portal, Math.random() * (14 * 16) + 16, 16 + (Math.random()*9) * 16 );

		if ( animate ){
			exit.tick();
		}

		if ( circleCollidesWithCircle( player.x, player.y, 12, exit.x, exit.y, 24 ) ){
			screenShake += 0.1;
			++exitFrames;
			if ( exitFrames > 120 ){
				finishMap();
			}
		} else {
			exitFrames = 0;
		}

	}

	function tickPickups(){

		var i = 0;
		var pickup : Pickup;
		var powerTileID : Int = spriteIndices.get( alternate ? pickup_power_a : pickup_power_b );
		while ( i < pickups.length ){

			pickup = pickups[i];
			pickup.lifetime -= 1;
			pickup.tick();

			if ( circleCollidesWithMap( pickup.x + pickup.vx, pickup.y, pickup.radius ) )
				pickup.vx = 0;
			if ( circleCollidesWithMap( pickup.x, pickup.y + pickup.vy, pickup.radius ) )
				pickup.vy = 0;
			pickup.x += pickup.vx;
			pickup.y += pickup.vy;

			if ( pickup.visible && pickup.pickupType == power )
				pickup.id = powerTileID;

			//P p p pickup a pickup
			if ( circleCollidesWithCircle( pickup.x, pickup.y, pickup.radius, player.x, player.y, 12 ) ){
				pickups.remove( pickup );
				gameview.removeTile( pickup );
				switch( pickup.pickupType ){
					default: 
						modifyTruePowerLevel( Math.max( 4, 16 - mapsComplete * 4 ) );
						playSound( pickup_power );
					case Pickup.PickupType.weapon_basic:
						setWeapon( PlayerWeapon.weapon_basic );
						playSound( pickup_weapon );
					case Pickup.PickupType.weapon_rapid:
						setWeapon( PlayerWeapon.weapon_rapid );
						playSound( pickup_weapon );
					case Pickup.PickupType.weapon_multi:
						setWeapon( PlayerWeapon.weapon_multi );
						playSound( pickup_weapon );
					case Pickup.PickupType.weapon_beam:
						setWeapon( PlayerWeapon.weapon_beam );
						playSound( pickup_weapon );
				}
				
			} else if ( pickup.lifetime <= 0 ) {
				pickups.remove( pickup );
				gameview.removeTile( pickup );
			} else {
				if ( pickup.lifetime < 60 && pickup.lifetime > 0 )
					pickup.visible = alternate;
			
				++i;
			}

		}

	}

	function modifyTruePowerLevel( delta : Float ){
		truePowerLevel = Math.min( 127, Math.max( 0, truePowerLevel + delta ) );
		if ( truePowerLevel <= 0 )
			gameover = true;
	}

	function tickGUI(){

		if ( displayedPowerLevel > truePowerLevel ){
			displayedPowerLevel -= 1;
			powerBarWhite.scaleX = Math.max(0,Math.round(displayedPowerLevel));
			powerBarGreen.scaleX = Math.max(0,Math.round( truePowerLevel ) );
		}

		if ( displayedPowerLevel < truePowerLevel ){

			displayedPowerLevel += 1;
			powerBarWhite.scaleX = Math.max(0,Math.round( truePowerLevel ) );
			powerBarGreen.scaleX = Math.max(0,Math.round( displayedPowerLevel ) );

		}

		if ( boss != null ){
			trueHealthLevel = 160 * boss.health / boss.maxHealth;
		}

		if ( displayedHealthLevel > trueHealthLevel ){

			displayedHealthLevel -= 1;
			healthBarWhite.scaleX = Math.max(0,Math.round(displayedHealthLevel));
			healthBarGreen.scaleX = Math.max(0,Math.round( trueHealthLevel ) );	

		}

		if ( displayedHealthLevel < trueHealthLevel ){
			
			displayedHealthLevel += 1;
			healthBarWhite.scaleX = Math.max(0,Math.round( trueHealthLevel ) );
			healthBarGreen.scaleX = Math.max(0,Math.round( displayedHealthLevel ) );

		}
		
		 modifyTruePowerLevel( -1/32 );

	}

	function tickEnemies(){

		var i = 0;
		var enemy : Enemy;
		while( i < enemies.length ){

			enemy = enemies[i];
			enemy.tick();
			if ( circleCollidesWithCircle( enemy.x, enemy.y, enemy.radius, player.x, player.y, 12 ) )
				playerHit();
			if ( circleCollidesWithMap( enemy.x + enemy.vx, enemy.y, enemy.radius ) )
				enemy.vx *= -0.5;
			if ( circleCollidesWithMap( enemy.x, enemy.y + enemy.vy, enemy.radius ) )
				enemy.vy *= -0.5;
			
			enemy.x += enemy.vx;
			enemy.y += enemy.vy;
			if ( enemy.isExpired ){
				enemies.remove( enemy );
				gameview.removeTile( enemy );
				switch( enemy.enemyType ){
					default:
						if ( Math.random() < 0.5 )
							spawnPowerPickup( enemy.x, enemy.y );
						playSound( explosion_small );
						spawnEffect( Effect.EffectType.explosion_small, enemy.x, enemy.y );
					case triangle:
						for ( i in 0...2 )
							spawnPowerPickup( enemy.x + Math.random() * 24 - 12, enemy.y + Math.random() * 24 - 12);
						playSound( explosion_medium );
						spawnEffect( Effect.EffectType.explosion_medium, enemy.x, enemy.y );
					case square:
						for ( i in 0...3 )
							spawnPowerPickup( enemy.x + Math.random() * 24 - 12, enemy.y + Math.random() * 24 - 12);
						playSound( explosion_medium );
						spawnEffect( Effect.EffectType.explosion_medium, enemy.x, enemy.y );
					case pentagon:
						bossDefeated = true;
						for ( i in 0...5 )
							spawnPowerPickup( enemy.x + Math.random() * 48 - 24, enemy.y + Math.random() * 48 - 24);
						spawnEffect( Effect.EffectType.explosion_large, enemy.x, enemy.y );
					case hexagon:
						bossDefeated = true;
						for ( i in 0...10 )
							spawnPowerPickup( enemy.x + Math.random() * 48 - 24, enemy.y + Math.random() * 48 - 24);											
						playSound( explosion_large );
						spawnEffect( Effect.EffectType.explosion_large, enemy.x, enemy.y );
					case octagon:
						bossDefeated = true;
						for ( i in 0...24 )
							spawnPowerPickup( enemy.x + Math.random() * 64 - 32, enemy.y + Math.random() * 64 - 32);
						playSound( explosion_large );
						spawnEffect( Effect.EffectType.explosion_large, enemy.x, enemy.y );
				}		

				//TODO spawn death effect
			} else
				++i;

		}

	}

	function tickWarnings(){

		var warningTime = minimapHiddenData[currentRoomIndex] == 5 ? 170 : 100;

		if ( warningFrames >= warningTime ){
			warningFrames = 0;

			playSound( spawn );

			while ( warnings.length > 0 ){
				var warning = warnings.pop();
				if ( minimapHiddenData[currentRoomIndex] == 5 ){
					var bossIndex = mapsComplete % 3;
					switch( bossIndex ){
						default:
							boss = spawnEnemy( pentagon, warning.x, warning.y );
						case 1:
							boss = spawnEnemy( hexagon, warning.x, warning.y );
						case 2:
							boss = spawnEnemy( octagon, warning.x, warning.y );
					}
				}
				else {
					var enemyRange = roomsEntered / 5 + mapsComplete*3;
					var enemyIndex : Int = Math.floor( Math.random() * enemyRange ) % 9;
					if ( enemyIndex < 2 )
						spawnEnemy( circle, warning.x, warning.y + 8 );
					else if ( enemyIndex < 5 )
						spawnEnemy( triangle, warning.x, warning.y + 16 );
					else if ( enemyIndex < 9 )
						spawnEnemy( square, warning.x, warning.y + 16 );
					else{
						spawnEnemy( circle, warning.x, warning.y + 8 );
					}					
				}
				gameview.removeTile( warning );
			}

		} else {

			var tileID = spriteIndices.get( alternate ? warning_a : warning_b );
			for ( tile in warnings )
				tile.id = tileID;

		}

		if ( warnings.length > 0 )
			++warningFrames;

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
		if ( getInputActive( InputType.shoot ) ){
			playerShoot();
			
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

		playerPainHead.visible = invincibleFrames > 15 || invincibleFrames > 0 && alternate;
		playerPainBody.visible = invincibleFrames > 15 || invincibleFrames > 0 && alternate;

		if ( invincibleFrames > 0 )
			--invincibleFrames;

		if ( reloadTime > 0 )
			--reloadTime;

	}

	function tickProjectiles(){

		var i = 0;
		var projectile : Projectile;
		while ( i < playerProjectiles.length ){
			projectile = playerProjectiles[i];
			projectile.x += projectile.vx;
			projectile.y += projectile.vy;

			for ( enemy in enemies ){
				if ( circleCollidesWithCircle( projectile.x, projectile.y, 8, enemy.x, enemy.y, enemy.radius + 2) ){
					projectile.isExpired = true;
					enemy.receiveHit();

				}
			}

			if ( projectile.x < -32 || projectile.x > gameview.width + 32 || projectile.y < -32 || projectile.y > gameview.height + 32 )
				projectile.isExpired = true;
			else if ( circleCollidesWithMap( projectile.x, projectile.y, 8 ) ){
				projectile.x += collisionVector.x;
				projectile.y += collisionVector.y;
				projectile.isExpired = true;
				spawnBulletHit( projectile.x, projectile.y );
			}

			if ( projectile.isExpired ){
				playerProjectiles.remove( projectile );
				gameview.removeTile( projectile );
				playSound( explosion_small );
				spawnEffect( Effect.EffectType.explosion_small, projectile.x, projectile.y );
			} else {
				++i;
				var effect = new Effect( Effect.EffectType.explosion_tiny, projectile.x + Math.random() * 4 - 8 - projectile.vx/2,  projectile.y + Math.random() * 4 - 8 - projectile.vy/2);
				effects.push( effect );
				gameview.addTileAt( effect, 0 );
				// spawnEffect( Effect.EffectType.explosion_tiny, projectile.x + Math.random() * 4 - 8,  projectile.y + Math.random() * 4 - 8 );
			}
	
		}

		i = 0;
		while ( i < enemyProjectiles.length ){
			projectile = enemyProjectiles[i];
			projectile.x += projectile.vx;
			projectile.y += projectile.vy;

			if ( circleCollidesWithCircle( projectile.x, projectile.y, 8, player.x, player.y, 12 ) ){
				projectile.isExpired = true;
				playerHit();
			}

			if ( projectile.x < -32 || projectile.x > gameview.width + 32 || projectile.y < -32 || projectile.y > gameview.height + 32 )
				projectile.isExpired = true;
			else if ( circleCollidesWithMap( projectile.x, projectile.y, 8 ) ){
				projectile.x += collisionVector.x;
				projectile.y += collisionVector.y;
				projectile.isExpired = true;
				spawnBulletHit( projectile.x, projectile.y );
			}

			if ( projectile.isExpired ){
				enemyProjectiles.remove( projectile );
				gameview.removeTile( projectile );
				playSound( explosion_small );
			} else 
				++i;
		}

	}

	function finishMap(){
		++mapsComplete;
		generateMap();
		modifyTruePowerLevel(32);
		setRoom( currentRoomIndex );
	}

	function spawnBulletHit( x : Float, y : Float ){
		screenShake += 0.2;
	}

	public function enemyShoot( enemy : Enemy ){

		var dx = player.x - enemy.x;
		var dy = player.y - enemy.y;
		var angle = Math.atan2( dy, dx ) * 180 / Math.PI + 90;

		angle += Math.random() * 20 - 10;

		var vx = Math.sin( angle * Math.PI/180 ) * 4;
		var vy = Math.cos( angle * Math.PI/180 ) * -4;

		var projectile = new Projectile( spriteIndices.get(bullet_enemy_a), enemy.x, enemy.y, vx, vy, 0 );
		enemyProjectiles.push( projectile );
		gameview.addTile( projectile );

	}

	function playerShoot(){

		var vx = Math.sin( playerHead.rotation * Math.PI/180 ) * 6;
		var vy = Math.cos( playerHead.rotation * Math.PI/180 ) * -6;

		if ( reloadTime > 0 )
			return;

		var projectile = null;

		switch( playerWeapon ){
			case weapon_none:
				return;
			case weapon_basic:
				reloadTime = 30;
				projectile = new Projectile( spriteIndices.get(bullet_player_b), player.x, player.y, vx, vy, playerHead.rotation );
				playerProjectiles.push( projectile );
				gameview.addTile( projectile );
			case weapon_rapid:
				reloadTime = 6;
				projectile = new Projectile( spriteIndices.get(bullet_player_a), player.x + vx + ( Math.random() * vy - vy/2), player.y + vy + (Math.random() * vx - vx/2), vx, vy, playerHead.rotation );
				playerProjectiles.push( projectile );
				gameview.addTile( projectile );
			case weapon_multi:
				reloadTime = 30;
				projectile = new Projectile( spriteIndices.get(bullet_player_b), player.x, player.y, vx, vy, playerHead.rotation );
				playerProjectiles.push( projectile );
				gameview.addTile( projectile );
				vx = Math.sin( (playerHead.rotation + 30)* Math.PI/180 ) * 6;
				vy = Math.cos( (playerHead.rotation +30)* Math.PI/180 ) * -6;
				projectile = new Projectile( spriteIndices.get(bullet_player_b), player.x, player.y, vx, vy, playerHead.rotation + 30 );
				playerProjectiles.push( projectile );
				gameview.addTile( projectile );
				vx = Math.sin( (playerHead.rotation - 30)* Math.PI/180 ) * 6;
				vy = Math.cos( (playerHead.rotation - 30)* Math.PI/180 ) * -6;
				projectile = new Projectile( spriteIndices.get(bullet_player_b), player.x, player.y, vx, vy, playerHead.rotation - 30 );
				playerProjectiles.push( projectile );
				gameview.addTile( projectile );
			case weapon_beam:
				return;
		}

		playSound( player_shot );		
		
	}

	function playerHit(){

		if ( invincibleFrames > 0 )
			return;

		playSound( SoundType.player_damage );
		modifyTruePowerLevel(-16);
		invincibleFrames = 30;

	}

	function tickDoors(){

		if ( roomComplete && doorProgress < 1 ){
			doorProgress = Math.min( 1, doorProgress + 0.016 );
			//TODO rumble sound
			//TODO door rumble screenshake
			screenShake = 0.2;
		}

		if ( !roomComplete && doorProgress > 0 ){
			doorProgress = Math.max( 0, doorProgress - 0.1 );
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

	public function spawnEnemy( enemyType : Enemy.EnemyType, x : Float, y : Float ){

		if ( enemies.length > 16 )
			return null;

		var enemy = new Enemy( enemyType, x, y );
		enemies.push( enemy );
		gameview.addTile( enemy );


		var particleCount : Int = 0;
		var particleRadius : Float;
		switch( enemyType ){
			case circle:
				spawnEffect( Effect.EffectType.explosion_small, x, y );
				particleCount = 4;
				particleRadius = 8;
			case triangle:
				spawnEffect( Effect.EffectType.explosion_medium, x, y );
				particleCount = 8;
				particleRadius = 24;
			case square:
				spawnEffect( Effect.EffectType.explosion_medium, x, y );
				particleCount = 10;
				particleRadius = 24;
			case pentagon:
				spawnEffect( Effect.EffectType.explosion_large, x, y );
				particleCount = 20;
				particleRadius = 48;
			case hexagon:
				spawnEffect( Effect.EffectType.explosion_large, x, y );
				particleCount = 30;
				particleRadius = 48;
			case octagon:
				spawnEffect( Effect.EffectType.explosion_large, x, y );
				particleCount = 40;
				particleRadius = 48;
				
		}

		for ( i in 0...particleCount )
			spawnEffect( Effect.EffectType.particle_portal, x - particleRadius/2 + particleRadius * Math.random(), y - particleRadius/2 + particleRadius * Math.random() );

		return enemy;

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
			worldContainer.removeChild( player );
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

		displayedPowerLevel = 0;
		truePowerLevel = 127;
		trueHealthLevel = 0;
		displayedHealthLevel = 0;
		playerWeapon = weapon_none;
		reloadTime = 0;
		invincibleFrames = 0;

		playerPainBody = new Bitmap( Assets.getBitmapData( "assets/playerPainBody.png" ) );
		playerPainBody.x = -12;
		playerPainBody.y = -12;
		playerPainHead = new Bitmap( Assets.getBitmapData( "assets/playerPainHead.png" ) );
		playerPainHead.x = headBMP.x;
		playerPainHead.y = headBMP.y;
		player.addChild( playerPainBody );
		playerHead.addChild( playerPainHead );

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

		var guiTileset = new Tileset( Assets.getBitmapData("assets/gui.png") );
		guiTileset.addRect( new Rectangle( 82, 32, 1, 6 ) ); //powerbar normal 0
		guiTileset.addRect( new Rectangle( 83, 32, 1, 6 ) ); //powerbar danger 1
		guiTileset.addRect( new Rectangle( 84, 32, 1, 6 ) ); //powerbar white 2
		guiTileset.addRect( new Rectangle( 0, 96, 32, 32 ) ); //Weapon icon basic 3
		guiTileset.addRect( new Rectangle( 32, 96, 32, 32 ) ); //Weapon icon rapid 4
		guiTileset.addRect( new Rectangle( 64, 96, 32, 32 ) ); //Weapon icon multi 5
		guiTileset.addRect( new Rectangle( 96, 96, 32, 32 ) ); //Weapon icon beam 6
		guiTileset.addRect( new Rectangle( 80, 32, 1, 16 ) ); //healthbar normal 7
		guiTileset.addRect( new Rectangle( 81, 32, 1, 16 ) ); //healthbar white 8
		spriteIndices.set( clock_0, guiTileset.addRect( new Rectangle( 0, 0, 12, 18 ) ) ); //clock digits
		spriteIndices.set( clock_1, guiTileset.addRect( new Rectangle( 12, 0, 12, 18 ) ) ); //clock digits
		spriteIndices.set( clock_2, guiTileset.addRect( new Rectangle( 24, 0, 12, 18 ) ) ); //clock digits
		spriteIndices.set( clock_3, guiTileset.addRect( new Rectangle( 36, 0, 12, 18 ) ) ); //clock digits
		spriteIndices.set( clock_4, guiTileset.addRect( new Rectangle( 48, 0, 12, 18 ) ) ); //clock digits
		spriteIndices.set( clock_5, guiTileset.addRect( new Rectangle( 60, 0, 12, 18 ) ) ); //clock digits
		spriteIndices.set( clock_6, guiTileset.addRect( new Rectangle( 72, 0, 12, 18 ) ) ); //clock digits
		spriteIndices.set( clock_7, guiTileset.addRect( new Rectangle( 84, 0, 12, 18 ) ) ); //clock digits
		spriteIndices.set( clock_8, guiTileset.addRect( new Rectangle( 96, 0, 12, 18 ) ) ); //clock digits
		spriteIndices.set( clock_9, guiTileset.addRect( new Rectangle( 108, 0, 12, 18 ) ) ); //clock digits
		
		gui = new Tilemap( 192, 64, guiTileset, false );
		addChild( gui );
		gui.y = 176;
		powerBarWhite = gui.addTile( new Tile( 2, 61, 29 ) );
		powerBarGreen = gui.addTile( new Tile( 0, 61, 29 ) );
		powerBarWhite.scaleX = 127;
		healthBarWhite = gui.addTile( new Tile( 8, 4, 4 ) );
		healthBarWhite.scaleX = 0;
		healthBarGreen = gui.addTile( new Tile( 7, 4, 4 ) );
		healthBarGreen.scaleX = 0;
		guiWeaponIcon = new Tile( 0, 4, 29 );
		gui.addTile( guiWeaponIcon );
		guiWeaponIcon.visible = false;
	}

	function setupSounds(){

		if ( sounds == null )
			sounds = new Map<SoundType, Array<Sound>>();

		sounds.set( SoundType.player_shot, [
			Assets.getSound("assets/audio/pshot_0.ogg"),
			Assets.getSound("assets/audio/pshot_1.ogg"),
			Assets.getSound("assets/audio/pshot_2.ogg"),
			Assets.getSound("assets/audio/pshot_3.ogg")
		]);

		sounds.set( SoundType.enemy_shot, [
			Assets.getSound("assets/audio/eshot_0.ogg"),
			Assets.getSound("assets/audio/eshot_1.ogg"),
			Assets.getSound("assets/audio/eshot_2.ogg"),
			Assets.getSound("assets/audio/eshot_3.ogg")
		]);

		sounds.set( SoundType.spawn, [
			Assets.getSound("assets/audio/spawn_0.ogg"),
			Assets.getSound("assets/audio/spawn_1.ogg"),
			Assets.getSound("assets/audio/spawn_2.ogg"),
			Assets.getSound("assets/audio/spawn_3.ogg")
		]);

		sounds.set( SoundType.explosion_small, [
			Assets.getSound("assets/audio/explode_0.ogg" )
		]);

		sounds.set( SoundType.explosion_medium, [
			Assets.getSound("assets/audio/explode_1.ogg" )
		]);

		sounds.set( SoundType.explosion_large, [
			Assets.getSound("assets/audio/explode_2.ogg" ),
			Assets.getSound("assets/audio/explode_3.ogg" )
		]);

		sounds.set( SoundType.door_slam, [
			Assets.getSound("assets/audio/door_slam.ogg" )
		]);

		sounds.set( SoundType.door_rumble, [
			Assets.getSound("assets/audio/door_rumble.ogg" )
		]);

		sounds.set( SoundType.pickup_weapon, [
			Assets.getSound("assets/audio/pickup_weapon.ogg" )
		]);
		
		sounds.set( SoundType.pickup_power, [
			Assets.getSound("assets/audio/pickup_power.ogg" )
		]);

		sounds.set( SoundType.player_damage, [
			Assets.getSound("assets/audio/pdamage_0.ogg" ),
			Assets.getSound("assets/audio/pdamage_1.ogg" ),
			Assets.getSound("assets/audio/pdamage_2.ogg" ),
			Assets.getSound("assets/audio/pdamage_3.ogg" )
		]);


	}

	function playSound( soundType : SoundType ){

		if ( soundTriggeredThisFrame )
			return;

		soundTriggeredThisFrame = true;

		var array = sounds.get( soundType );
		array[Math.floor(array.length * Math.random() )].play();

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

	public function setWeapon( weapon : Game.PlayerWeapon ){

		guiWeaponIcon.visible = true;
		playerWeapon = weapon;
		switch( playerWeapon ){
			case weapon_none:
				guiWeaponIcon.visible = false;
			case weapon_basic:
				guiWeaponIcon.id = 3;
			case weapon_rapid:
				guiWeaponIcon.id = 4;
			case weapon_multi:
				guiWeaponIcon.id = 5;
			case weapon_beam:
				guiWeaponIcon.id = 6;
		}

	}

	function completeRoom(){

		roomComplete = true;
		roomsComplete[currentRoomIndex] = true;
		playSound( door_rumble );

	}

	//Configure a room
	function setRoom( roomIndex : Int ){

		var roomType = minimapHiddenData[currentRoomIndex];
		if ( roomType == 5 )
			trueHealthLevel = 160;
		boss = null;
		var room = roomData[roomIndex];
		roomComplete = roomsComplete[roomIndex];
		completeFrames = 0;

		if ( roomTiles == null )
			roomTiles = new Array<Tile>();

		while ( roomTiles.length > 0 )
			gameview.removeTile( roomTiles.pop() );

		if ( backgroundTiles == null )
			backgroundTiles = new Array<Tile>();

		//Remove any effects
		if ( effects == null )
			effects = new Array<Effect>();

		while ( effects.length > 0 )
			gameview.removeTile( effects.pop() );

		//Remove any warnings
		if ( warnings == null )
			warnings = new Array<Tile>();

		while ( warnings.length > 0 )
			gameview.removeTile( warnings.pop() );

		warningFrames = 0;

		//Remove exit
		if ( exit != null ){
			gameview.removeTile( exit );
			exit = null;
		}
		exitFrames = 0;

		if ( bossDefeated && ( roomType == 9 || roomType == 10 ) ){
			exit = new Exit();
			gameview.addTile( exit );
			completeFrames = 3000;
		}

		//Remove any enemies
		if ( enemies == null )
			enemies = new Array<Enemy>();

		while ( enemies.length > 0 ){
			gameview.removeTile( enemies.pop() );
		}

		//Remove any pickups
		if ( pickups == null )
			pickups = new Array<Pickup>();

		while ( pickups.length > 0 )
			gameview.removeTile( pickups.pop() );

		//Remove any player projectiles
		if ( playerProjectiles == null )
			playerProjectiles = new Array<Projectile>();

		while ( playerProjectiles.length > 0 )
			gameview.removeTile( playerProjectiles.pop() );

		//Remove any enemy projectiles
		if ( enemyProjectiles == null )
			enemyProjectiles = new Array<Projectile>();

		while( enemyProjectiles.length > 0 )
			gameview.removeTile( enemyProjectiles.pop() );

		while ( backgroundTiles.length > 0 )
			gameview.removeTile( backgroundTiles.pop() );

		var tileSetIndex = (mapsComplete + Math.random() < 0.2 ? 1 : 0 )% 3;
						

		//Spawn tiles and warnings and optionally a weapon
		for ( y in 0...11 ){
			for ( x in 0...16 ){
				var i = x + y * 16;
				var v = room[i];
				if ( v > 0 ){
					var tile = new Tile(v, x * 16, y * 16);
					roomTiles.push( gameview.addTile( tile ) );
				} 
				if ( v == -1 && !roomComplete && roomsEntered > 0 ){
					spawnWarning( x * 16 - 8, y * 16 - 8 );
				}
				
			}
		}

		if ( roomsEntered == 0 && mapsComplete == 0 ){

			if ( Math.random() < 0.1 )
				spawnWeaponPickup( weapon_rapid, 192, 48 );
			else
				spawnWeaponPickup( weapon_basic, 128, 48 );
		}

		addNeighbouringRoomsToMinimap();
		if ( !roomComplete )
			playSound( door_slam );

	}

	public function spawnWeaponPickup( weaponType : PlayerWeapon, px : Float, py : Float ){

		var pickupType = Pickup.PickupType.weapon_basic;
		switch( weaponType ){
			default:
			case PlayerWeapon.weapon_multi:
				pickupType = Pickup.PickupType.weapon_multi;
			case PlayerWeapon.weapon_rapid:
				pickupType = Pickup.PickupType.weapon_rapid;
			case PlayerWeapon.weapon_beam:
				pickupType = Pickup.PickupType.weapon_beam;
		}
		var pickup = new Pickup( pickupType, px, py );
		pickups.push( pickup );
		gameview.addTile( pickup );

	}

	function spawnPowerPickup( px : Float, py : Float ){

		if ( boss != null && trueHealthLevel > 0 && truePowerLevel > 32 )
			return;

		var pickup = new Pickup( Pickup.PickupType.power, px, py );
		var dx = px - player.x;
		var dy = py - player.y;
		pickup.vx = dx/30;
		pickup.vy = dy/30;
		gameview.addTile( pickup );
		pickups.push( pickup );

	}

	function spawnWarning( px : Float, py : Float ){

		var tile = new Tile( spriteIndices.get( warning_a ), px -2, py-4 );
		warnings.push( gameview.addTile( tile ) );

	}

	function spawnEffect( effectType : Effect.EffectType, x : Float, y : Float ){

		var effect = new Effect( effectType, x, y );
		effects.push( effect );
		gameview.addTile( effect );

	}

	function tickEffects(){

		if ( !animate )
			return;

		var i = 0;
		var effect : Effect;
		while ( i < effects.length ){

			effect = effects[i];
			effect.tick();

			if ( effect.isExpired ){
				gameview.removeTile( effect );
				effects.remove( effect );
			} else {
				++i;
			}

		}

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
		defineSprite( 0, 48, 48, 48, SpriteType.exit );
		for ( i in 1...4 )
			tileset.addRect( new Rectangle( i * 48, 48, 48, 48 ) );

		//Enemies
		//Circle
		defineSprite( 176, 176, 16, 16, enemy_circle_l );
		defineSprite( 176, 192, 16, 16, enemy_circle_r );
		defineSprite( 192, 208, 16, 16, enemy_circle_damage );
		//Triangle
		defineSprite( 0, 96, 32, 32, enemy_triangle_l );
		defineSprite( 32, 96, 32, 32, enemy_triangle_r );
		defineSprite( 64, 96, 32, 32, enemy_triangle_damage );
		//Square
		defineSprite( 96, 96, 32, 32, enemy_square_l );
		defineSprite( 128, 96, 32, 32, enemy_square_r );
		defineSprite( 160, 96, 32, 32, enemy_square_damage );
		//Pentagon
		defineSprite( 0, 128, 48, 48, enemy_pentagon );
		defineSprite( 48, 128, 48, 48, enemy_pentagon_damage );
		//Hexagon
		defineSprite( 96, 128, 48, 48, enemy_hexagon );
		defineSprite( 144, 128, 48, 48, enemy_hexagon_damage );
		//Octagon
		defineSprite( 192, 80, 64, 64, enemy_octagon );
		defineSprite( 192, 144, 64, 64, enemy_octagon_damage );

		//Pickups
		defineSprite( 0, 176, 16, 16, pickup_power_a );
		defineSprite( 16, 176, 16, 16, pickup_power_b );
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
		defineSprite( 224, 224, 32, 32 );
		defineSprite( 192, 208, 16, 16, explosion_small );
		defineSprite( 208, 208, 16, 16 );
		defineSprite( 224, 208, 8, 8, explosion_tiny );
		defineSprite( 232, 208, 8, 8 );

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

	function circleCollidesWithCircle( ax : Float, ay : Float, ar : Float, bx : Float, by : Float, br : Float ) : Bool {

		var PointA = new Point( ax, ay );
		var PointB = new Point( bx, by );
		return Point.distance(PointA, PointB) <= ar + br;

	}

	function circleCollidesWithMap( circleX : Float, circleY : Float, circleR : Float ) : Bool {

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
				#if html5
				#else
				Sys.exit(0);
				#end
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

	/* Update the minimap with nearby rooms including the current room */
	function addNeighbouringRoomsToMinimap(){

		if ( minimapData[currentRoomIndex] % 2 == 1 ){
			minimapData[currentRoomIndex] += 1;
			++roomsEntered;
		}
		//look for doors
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

	function setupClock(){

		if ( clockDigits == null ){
			clockDigits = new Array<Tile>();
		}

		clockFrames = 0;

		while( clockDigits.length > 0 )
			gui.removeTile( clockDigits.pop() );

		clockDigits.push( gui.addTile( new Tile ( spriteIndices.get( SpriteType.clock_8 ), 68, 41 ) ) );
		clockDigits.push( gui.addTile( new Tile ( spriteIndices.get( SpriteType.clock_8 ), 82, 41 ) ) );

		clockDigits.push( gui.addTile( new Tile ( spriteIndices.get( SpriteType.clock_8 ), 102, 41 ) ) );
		clockDigits.push( gui.addTile( new Tile ( spriteIndices.get( SpriteType.clock_8 ), 118, 41 ) ) );

		clockDigits.push( gui.addTile( new Tile ( spriteIndices.get( SpriteType.clock_8 ), 136, 41 ) ) );
		clockDigits.push( gui.addTile( new Tile ( spriteIndices.get( SpriteType.clock_8 ), 150, 41 ) ) );


	}

	function updateClock(){

		++clockFrames;
		var clockBaseFrame : Int = spriteIndices.get( clock_0 );

		clockSeconds = Math.floor(clockFrames / 60);
		clockMinutes = Math.floor(clockSeconds / 60);

		clockDigits[0].id = clockBaseFrame + Math.floor(clockMinutes / 10);
		clockDigits[1].id = clockBaseFrame + Math.floor(clockMinutes % 10);
		var displaySeconds = clockSeconds % 60;
		clockDigits[2].id = clockBaseFrame + Math.floor(displaySeconds / 10);
		clockDigits[3].id = clockBaseFrame + Math.floor(displaySeconds % 10);
		var displayFrames = clockFrames % 60;
		clockDigits[4].id = clockBaseFrame + Math.floor(displayFrames / 10);
		clockDigits[5].id = clockBaseFrame + Math.floor( displayFrames % 10);


	}

	function drawMinimap(){

		var mapTileSize = 12;

		if ( minimap == null ){
			var minimapTileset = new Tileset( Assets.getBitmapData("assets/gui.png") );
			spriteIndices.set( minimap_currentRoom, minimapTileset.addRect( new Rectangle( 4, 36, 12, 12 ) ) ); //Current room indicator 0
			spriteIndices.set( minimap_unexploredRoom, minimapTileset.addRect( new Rectangle( 24, 32, 8, 8 ) ) ); //unexplored room 1
			spriteIndices.set( minimap_exploredRoom, minimapTileset.addRect( new Rectangle( 16, 32, 8, 8 ) ) ); //explored room 2
			spriteIndices.set( minimap_unexploredBoss, minimapTileset.addRect( new Rectangle( 64, 32, 12, 12 ) ) ); //unexplored boss room 3
			spriteIndices.set( minimap_exploredBoss, minimapTileset.addRect( new Rectangle( 48, 32, 12, 12 ) ) ); //explored boss
			spriteIndices.set( minimap_unexploredExit, minimapTileset.addRect( new Rectangle( 24, 40, 8, 8 ) ) ); //unexplored exit 5
			spriteIndices.set( minimap_exploredExit, minimapTileset.addRect( new Rectangle( 16, 40, 8, 8 ) ) ); //explored exit 5
			spriteIndices.set( minimap_doorH, minimapTileset.addRect( new Rectangle( 0, 32, 4, 2 ) ) ); //door h 6
			spriteIndices.set( minimap_doorV, minimapTileset.addRect( new Rectangle( 0, 32, 2, 4 ) ) ); //door v 7

			minimap = new Tilemap( 60, 60, minimapTileset, false );
			addChild( minimap );
			minimap.x = 194;
			minimap.y = 178;
		}

		//Clear minimap
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
						minimap.addTile( new Tile( spriteIndices.get( minimap_doorV ), dx + 3, dy -4 ) );
					if ( doorData[1] )
						minimap.addTile( new Tile( spriteIndices.get( minimap_doorH ), dx + mapTileSize - 4, dy +3 ) );
					if ( doorData[2] )
						minimap.addTile( new Tile( spriteIndices.get( minimap_doorV ), dx + 3, dy + mapTileSize - 4) );
					if ( doorData[3] )
						minimap.addTile( new Tile( spriteIndices.get( minimap_doorH ), dx - 4, dy + 3 ) );

					var tileIndex = 0;

					switch( minimapData[i] ){
						default: 
						case 1:
							tileIndex = spriteIndices.get( minimap_unexploredRoom );
						case 2, 7, 8:
							tileIndex = spriteIndices.get( minimap_exploredRoom );
						case 5:
							tileIndex = spriteIndices.get( minimap_unexploredBoss );
							dx -= 1;
							dy -= 2;
						case 6:
							tileIndex = spriteIndices.get( minimap_exploredBoss );
							dx -= 1;
							dy -= 2;
						case 9:
							tileIndex = spriteIndices.get( minimap_unexploredExit );
						case 10:
							tileIndex = spriteIndices.get( minimap_exploredExit );
					}

					//room
					if ( tileIndex > 0 ){
						var tile = new Tile( tileIndex, dx, dy );
						minimap.addTile( tile );
					}
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

		roomsEntered = 0;

		var mapLayout = mapLibrary[( mapsComplete % 3 + 1) * Math.floor(Math.random() * 5)%mapLibrary.length];

		bossDefeated = false;

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

		var doorUp = false;
		var doorRight = false;
		var doorDown = false;
		var doorLeft = false;

		for ( y in 0...mapHeight ){

			for ( x in 0...mapWidth ){

				var mapIndex = x + y * mapWidth;
				var index = x + y * 5;
				var roomType = mapLayout[index];

				doorUp = index > 5 && mapLayout[index-5] != 0;
				doorRight = index % 5 != 4 && mapLayout[index+1] != 0;
				doorDown = index < 20 && mapLayout[index+5] != 0;
				doorLeft = index % 5 != 0 && mapLayout[index-1] != 0;

				var newRoom : Array<Int>;
				switch( roomType ){
					default: //blank room
						newRoom = roomLayoutLibrary[0];
					case 1: //Normal room
						newRoom = generateNormalRoom( doorUp, doorRight, doorDown, doorLeft );
					case 5: //Boss
						newRoom = generateBossRoom( doorUp, doorRight, doorDown, doorLeft );
					case 7: //Entrance
						newRoom = generateEntryRoom( doorUp, doorRight, doorDown, doorLeft );
						currentRoomIndex = index;
					case 9: //Exit
						newRoom = generateEntryRoom( doorUp, doorRight, doorDown, doorLeft );						
				}
				
				for ( i in 0...newRoom.length ){
					var v = newRoom[i];
					if ( v == 1 ){ //Pick a random tile 
						newRoom[i] = getRandomTileIndex();
					}
				}

				roomData.push( newRoom );
				minimapHiddenData.push( roomType );
			}
		}		

		//Fix the first room not showing properly in minimap until moving
		minimapData[currentRoomIndex] = minimapHiddenData[currentRoomIndex];
	}

	/* Return a solid map tile index from the right palette */
	function getRandomTileIndex () : Int{

		var tileBaseIndex = (mapsComplete + (Math.random() < 0.333 ? 1 : 0 ) ) % 3;
		var tileBase = spriteIndices.get( tileSetA );
		switch( tileBaseIndex ){
			default:
			case 1:
				tileBase = spriteIndices.get( tileSetB );
			case 2:
				tileBase = spriteIndices.get( tileSetC );
		}
		var t = tileBase + Math.floor( Math.random() * 8 ); 
		if ( t == 0 )
			t = 1;
		
		return t;

	}

	function generateNormalRoom( doorUp : Bool, doorRight : Bool, doorDown : Bool, doorLeft : Bool ) : Array<Int> {

		if ( roomLayoutLibrary == null )
			setupRoomDataLibrary();

		var index : Int = 0;
		//Normal room 0-5
		index = Math.floor( Math.random() * 4 ) + 1;

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
			if ( v == 1 ) {//Pick a random tile 
				room[i] += Math.floor( Math.random() * 8 ) + Math.random() < 0.5 ? 16 : 0;
			}
			if ( v == 9 )
				room[i] = -1;
		}

		return room;
	}

	function generateEntryRoom( doorUp: Bool, doorRight: Bool, doorDown: Bool, doorLeft: Bool ){

		if ( roomLayoutLibrary == null )
			setupRoomDataLibrary();

		var index : Int = 9;
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

		return room;

	}

	function generateBossRoom( doorUp : Bool, doorRight : Bool, doorDown : Bool, doorLeft : Bool ){

		var room = roomLayoutLibrary[10].copy();
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
			if ( v == 9 )
				room[i] = -1;
		}

		return room;

	}



	function setupRoomDataLibrary(){

		roomLayoutLibrary = new Array<Array<Int>>();
		//0 Blank room
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
			]);
		
		//1, 2, 3, 4 Centre Obstacle rooms
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 9, 0, 0, 1, 1, 0, 0, 9, 0, 0, 0, 0,
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
			 1, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
			 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1,
			 1, 0, 0, 1, 1, 0, 0, 9, 0, 0, 0, 1, 1, 0, 0, 1,
			 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0,
			 1, 0, 0, 1, 1, 0, 0, 0, 9, 0, 0, 1, 1, 0, 0, 1,
			 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
			 1, 0, 0, 0, 9, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
			 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);

		// 5 Blocked top
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
			 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
			 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1,
			 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 0,
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
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 1, 1, 1,
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
			 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 0,
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
			 1, 1, 1, 1, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 1, 1, 1, 1, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);
		// 9 Entry
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1
			]);
		// 10 Boss
		roomLayoutLibrary.push([ 
			 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0,
			 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
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

		mapLibrary = new Array<Array<Int>>();
		//Level 1 0,1,2,4,5
		mapLibrary.push([
			0, 0, 0, 0, 0,
			0, 0, 0, 0, 0,
			1, 1, 5, 1, 7,
			1, 0, 0, 0, 0,
			9, 0, 0, 0, 0
		]);
		mapLibrary.push([
			0, 0, 0, 0, 0,
			0, 0, 0, 0, 0,
			1, 1, 5, 1, 9,
			1, 0, 0, 0, 0,
			7, 0, 0, 0, 0
		]);
		mapLibrary.push([
			0, 9, 0, 0, 0,
			0, 1, 0, 0, 0,
			0, 5, 1, 1, 0,
			0, 0, 0, 7, 0,
			0, 0, 0, 0, 0
		]);		
		mapLibrary.push([
			0, 0, 7, 0, 0,
			0, 1, 5, 0, 0,
			1, 1, 0, 0, 0,
			0, 1, 1, 0, 0,
			0, 0, 9, 0, 0
		]);
		mapLibrary.push([
			0, 1, 7, 0, 0,
			0, 1, 0, 0, 1,
			0, 1, 5, 1, 1,
			0, 0, 0, 1, 0,
			0, 0, 0, 9, 0
		]);	
		// Level 2
		mapLibrary.push([
			7, 1, 1, 1, 1,
			0, 1, 0, 0, 1,
			0, 1, 1, 1, 1,
			0, 1, 0, 1, 0,
			0, 5, 0, 9, 0
		]);	
		mapLibrary.push([
			0, 0, 0, 0, 1,
			9, 0, 0, 5, 1,
			1, 1, 0, 0, 1,
			1, 1, 1, 1, 1,
			1, 0, 7, 0, 0
		]);	
		mapLibrary.push([
			0, 0, 0, 0, 1,
			5, 0, 0, 1, 1,
			1, 1, 0, 0, 1,
			1, 1, 1, 1, 1,
			9, 0, 7, 0, 0
		]);	
		mapLibrary.push([
			0, 0, 0, 0, 9,
			1, 0, 0, 5, 1,
			1, 0, 0, 0, 1,
			1, 1, 1, 1, 1,
			1, 0, 7, 0, 0
		]);	
		mapLibrary.push([
			0, 0, 1, 0, 0,
			0, 0, 1, 0, 9,
			1, 1, 7, 1, 1,
			0, 0, 1, 0, 0,
			0, 5, 1, 0, 0
		]);	


		mapLibrary.push([
			0, 0, 0, 0, 0,
			0, 0, 0, 0, 0,
			0, 0, 0, 0, 0,
			0, 0, 0, 0, 0,
			0, 0, 0, 0, 0
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
	minimap_unexploredRoom;
	minimap_exploredRoom;
	minimap_unexploredExit;
	minimap_exploredExit;
	minimap_unexploredBoss;
	minimap_exploredBoss;
	minimap_currentRoom;
	minimap_doorH;
	minimap_doorV;
	clock_0;
	clock_1;
	clock_2;
	clock_3;
	clock_4;
	clock_5;
	clock_6;
	clock_7;
	clock_8;
	clock_9;
	

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

enum PlayerWeapon {

	weapon_none;
	weapon_basic;
	weapon_multi;
	weapon_rapid;
	weapon_beam;

}

enum SoundType {

	player_shot;
	enemy_shot;
	spawn;
	explosion_small;
	explosion_medium;
	explosion_large;
	door_rumble;
	door_slam;
	pickup_weapon;
	pickup_power;
	player_damage;

}
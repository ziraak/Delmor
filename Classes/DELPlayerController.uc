/**
 * Extended playercontroller that changes the camera.
 * 
 * KNOWN BUGS:
 * - Fix player movement.
 * 
 * @author Anders Egberts.
 */
class DELPlayerController extends PlayerController dependson(DELInterface)
	config(Game);

var SoundCue soundSample; 
var() bool canWalk, drawDefaultHud, drawBars, drawSubtitles, hudLoaded;

var() private string subtitle;
var() int subtitleTime, currentTime;

/*##########
 * STATES
 #########*/

function BeginState(Name PreviousStateName){
	super.BeginState(PreviousStateName);
	self.showSubtitle("Old: " $ PreviousStateName $ " | New: " $ GetStateName());
}

auto state PlayerWalking {
Begin:
	Sleep(0.1); gotoState('Playing');
}

state Playing extends PlayerWalking{
	function BeginState(Name PreviousStateName){
		self.showSubtitle("Old: " $ PreviousStateName $ " | New: " $ GetStateName());
	}

Begin:
	canWalk = true;
	drawDefaultHud = true;
	drawBars = true;
	drawSubtitles = true;
	checkHuds();
}

state MouseState {
	function UpdateRotation(float DeltaTime);   
	exec function StartFire(optional byte FireModeNum);
	exec function StopFire(optional byte FireModeNum);

	function load(){
		canWalk=false;
		drawDefaultHud=true;
		addInterfacePriority(class'DELInterfaceMouse', HIGH);
	}
}

state Pauses extends MouseState{

Begin:
	load();
	drawBars = false;
	drawSubtitles = true;
	checkHuds();
	addInterface(class'DELInterfacePause');
}

state End extends MouseState{

Begin:
	load();
	drawBars = false;
	drawSubtitles = true;
	checkHuds();
}

state Inventory extends MouseState{

 Begin:
	load();
	drawBars = true;
	drawSubtitles = true;
	checkHuds();

	addInterface(class'DELInterfaceInventory');
}

function swapState(name StateName){
	if (StateName == GetStateName()) {
		if (StateName == 'Playing') {
			StateName = 'Pauses';
		} else {
			StateName = 'Playing';
		}
	}
	`log("-- Switching state to "$StateName$"--");
	getHud().clearInterfaces();
	ClientGotoState(StateName);
}

/*#####################
 * Button press events
 ####################*/

exec function openInventory(){
	swapState('Inventory');
}

exec function closeHud(){
	swapState('Playing');
}

public function onNumberPress(int key){
	local DELinterface interface;
	local array<DELInterface> interfaces;

	interfaces = getHud().getInterfaces();
	foreach interfaces(interface){
		if (DELInterfaceInteractible(interface) != None){
			DELInterfaceInteractible(interface).onKeyPress(getHud(), key);
		}
	}
}

public function onMousePress(IntPoint pos, bool left){
	local DELinterface interface;
	local array<DELInterface> interfaces;

	interfaces = getHud().getInterfaces();
	foreach interfaces(interface){
		if (DELInterfaceInteractible(interface) != None){
			DELInterfaceInteractible(interface).onClick(getHud(), pos, left);
		}
	}
}

/*################
 * HUD functions
 ###############*/

function checkHuds(){
	if (getHud() == None)return;

	if (drawDefaultHud){
		addInterface(class'DELInterfaceBar');
		addInterface(class'DELInterfaceCompass');
	}
	if (drawSubtitles){
		addInterface(class'DELInterfaceSubtitle');
	}
	if (drawbars){
		//addInterface(class'DELInterfaceHealthBars');
	}
	hudLoaded = true;
}

function addInterface(class<DELInterface> interface){
	addInterfacePriority(interface, NORMAL);
}

function addInterfacePriority(class<DELInterface> interface, EPriority priority){
	local DELInterface delinterface;

	if (getHud() == None){`log("HUD IS NONE! check bUseClassicHud"); return;}
	`log("Added interface"@interface);
	
	delinterface = Spawn(interface, self);
	getHud().addInterface(delinterface, priority);
	delinterface.load(getHud());
}

public function showSubtitle(string text){
	subtitle = text;
	currentTime = getSeconds();
}

/*################
 * Util functions
 ###############*/

simulated function PostBeginPlay() {
	
	super.PostBeginPlay();
}

/**
 * Overriden function from PlayerController. In this version the pawn will not rotate with
 * the camera. However when the player moves the mouse, the camera will rotate.
 * @author Anders Egberts
 */
function UpdateRotation(float DeltaTime)
{
    local DELPawn dPawn;
	local float pitchClampMin , pitchClampMax;
	local Rotator	DeltaRot, newRotation, ViewRotation;

	pitchClampMax = -15000.0;
	pitchClampMin = 4500.0;

    //super.UpdateRotation(DeltaTime);

    dPawn = DELPawn(self.Pawn);

	if (canWalk){
		ViewRotation = Rotation;

		// Calculate Delta to be applied on ViewRotation
		DeltaRot.Yaw	= PlayerInput.aTurn;
		DeltaRot.Pitch	= PlayerInput.aLookUp;

		ProcessViewRotation( DeltaTime, ViewRotation, DeltaRot );
		SetRotation(ViewRotation);

		ViewShake( deltaTime );

		NewRotation = ViewRotation;
		NewRotation.Roll = Rotation.Roll;

		if (dPawn != none){
			//Constrain the pitch of the player's camera.
			dPawn.camPitch = Clamp( dPawn.camPitch + self.PlayerInput.aLookUp , pitchClampMax , pitchClampMin );
			//dPawn.camPitch = dPawn.camPitch + self.PlayerInput.aLookUp;
		}
	} else {
		//Mouse event
	}
}

/*##########
 * Getters
 #########*/

function DELPlayerHud getHud(){
	return DELPlayerHud(myHUD);
}

function DELPawn getPawn(){
	return DELPawn(self.Pawn);
}

public function String getSubtitle(){
	local int totalTime;
	if (subtitle == "" || currentTime == 0) return "";

	totalTime = currentTime+subtitleTime;

	//time less then seconds or time after the 59 seconds, so check adding+60 starting from 0
	if (totalTime <= getSeconds() + (totalTime > 59 && getSeconds() < currentTime) ? 60 : 0){
		subtitle = "";
		currentTime = 0;
	}

	return subtitle;
}

public function int getSeconds(){
	local int sec, a;
	GetSystemTime(a,a,a,a,a,a,sec,a);
	return sec;
}

exec function SaveGame(string FileName)
{
    local DELSaveGameState GameSave;

    // Instance the save game state
    GameSave = new class'DELSaveGameState';

    if (GameSave == None)
    {
		return;
    }

    ScrubFileName(FileName);    // Scrub the file name
    GameSave.SaveGameState();   // Ask the save game state to save the game

    // Serialize the save game state object onto disk
    if (class'Engine'.static.BasicSaveObject(GameSave, FileName, true, class'DELSaveGameState'.const.VERSION))
    {
        // If successful then send a message
		ClientMessage("Saved game state to " $ FileName $ ".", 'System');
    }
}

exec function LoadGame(string FileName)
{
    local DELSaveGameState GameSave;

    // Instance the save game state
    GameSave = new class'DELSaveGameState';

    if (GameSave == None)
    {
		return;
    }

    // Scrub the file name
    ScrubFileName(FileName);

    // Attempt to deserialize the save game state object from disk
    if (class'Engine'.static.BasicLoadObject(GameSave, FileName, true, class'DELSaveGameState'.const.VERSION))
    {
        // Start the map with the command line parameters required to then load the save game state
		ConsoleCommand("start " $ GameSave.PersistentMapFileName $ "?Game=DELSaveGameState.DELGame?DELSaveGameState=" $ FileName);
    }
	GameSave.LoadGameState();
}

function ScrubFileName(out string FileName)
{
    // Add the extension if it does not exist
    if (InStr(FileName, ".sav",, true) == INDEX_NONE)
    {
		FileName $= ".sav";
    }

    FileName = Repl(FileName, " ", "_");                            // If the file name has spaces, replace then with under scores
    FileName = class'DELSaveGameState'.const.SAVE_LOCATION $ FileName; // Prepend the filename with the save folder location
	`log(FileName);
}

DefaultProperties
{
	InputClass=class'DELPlayerInput'
	subtitleTime=5
}

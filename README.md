Spyglass
========

## Usage

Get _Spyglass_ code

	git clone git@github.com:acoomans/Spyglass.git
	
Then drag and drop the _Spyglass_ directory in your project

To get the dependancies, get the submodules:

	cd Spyglass
	git submodule update --init --recursive
	
Then drag and drop the _Base64/Base64_ and _OpenUDID_ directories in your project.

Note: Disable _ARC_ for _OpenUDID.m_ ( _-fno-objc-arc_ ).


## Tracking

First, setup _Spyglass_ server url:

    [ACSpyglass sharedInstance].serverURL = @"http://www.example.com/api/1";
    
Optionaly, you can track the user:

    [ACSpyglass sharedInstance].userIdentifier = @"black beard";
    
Track event:

    [[ACSpyglass sharedInstance] track:@"Attack!" properties:@{
        @"roll" : [NSNumber numberWithInt:arc4random() % 74]
     }];
     

## Events

Events have the following format:

- _deviceIdentifier_: a string, defaults to openUUID
- _userIdentifier_: a string identifying the user, to be set manually
- _timestamp_: an integer, number of seconds since epoch
- _event_: a string, name of the event to track
- _properties_: a dictionary, containing any extra parameters needed

Events are sent by batch regularly (10 seconds by default). Events are sent as JSON encoded in base64.
Example:

    [
        {   'deviceIdentifier': 'bd95a47b733e4e06dae8c55c7adb055b3e207e2b',
            'event': 'Attack!',
            'properties': {   'roll': 28},
            'time': 1363203126,
            'userIdentifier': 'black beard'},
        {   'deviceIdentifier': 'bd95a47b733e4e06dae8c55c7adb055b3e207e2b',
            'event': 'Attack!',
            'properties': {   'roll': 67},
            'time': 1363203129,
            'userIdentifier': 'black beard'},
        {   'deviceIdentifier': 'bd95a47b733e4e06dae8c55c7adb055b3e207e2b',
            'event': 'Attack!',
            'properties': {   'roll': 58},
            'time': 1363203132,
            'userIdentifier': 'black beard'}
    ]

The server should return a json with result and code:

    {
		'result': "ok",
		'code': 0
	}
    
If the code is not 0, the events are considered as not recorded and will be kept in _Spyglass_ queue and sent again in the next batch.

The server should check for duplicates before recording any event.


## Documentation

install appledoc:

`brew install appledoc`

build the _Documentation_ target,

the documentation will be automatically added to Xcode.


## Testing

Run the server:

    cd server
    pip install -r requirements.txt
    python server.py
    
Then run the _SpyglassDemo_ target from Xcode
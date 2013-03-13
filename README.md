Spyglass
========

## Usage

	git clone git@github.com:acoomans/Spyglass.git
	
Then drag and drop the _Spyglass_ directory in your project


## Dependencies

To get the submodules:

	cd Spyglass
	git submodule update --init --recursive
	
Then drag and drop the _Base64/Base64_ and _OpenUDID_ in your project.

Disable _ARC_ for _OpenUDID.m_ ( _-fno-objc-arc_ )


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
    
Then run the _SpyglassDemo_ target
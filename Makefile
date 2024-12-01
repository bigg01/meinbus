build:
	# @pyinstaller -w -F --add-data "templates:templates" --add-data "static:static" --onefile --noconsole --icon=icon.ico meinbus.py
	@pyinstaller -w -F --onefile --noconsole --icon=icon.ico meinbus.py

clean:
	@rm -rf build/ dist/ __pycache__ *.spec


run:
	@python3 meinbus.py


docker-build:
	@docker build -t meinbus .
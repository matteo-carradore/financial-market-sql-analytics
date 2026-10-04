.PHONY: build report test demo
build:   ; python3 build_db.py
demo:    ; python3 build_db.py --simulate
report:  ; python3 report.py
test:    ; python3 -m unittest discover -s tests -v

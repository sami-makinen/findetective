# README

Findetective is a competition entry to detect Finnish sentences from
Caesar encrypted input. The core of detection algorithm is under spy/
-directory and rails app wraps results to html-page.

Install Ruby (2.5.5) and Rails (6.0.0).

To get see result on web browser:

$ cd findetective
$ rails server

Go to 'http://localhost:3000/spy/index' to see result.

From console

$ rails console
> Spy::Agent.instance.loadall
> Spy::Agent.instance.run

See also README under spy/ -directory.


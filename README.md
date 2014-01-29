aviation
========

Aviation related scripts and programs

This script was originally written around 2003 and recently updated to implement new data sources for METAR information.  The TAF datasource has not been updated, nor has the web scraping code that was utilized by the airport,navaid and metar-detail options.

This code is licensed under the BSD 2-clause license (see LICENSE).

## Usage ##

    $ ./av.pl (metar | taf | metar-decode | metar-detail | metar-debug | airport | navaid) <arguments>

### What works ###

    av.pl metar ICAO-code
    av.pl metar-decode ICAO-code
    av.pl metar-debug metar-code

The `metar` option takes an ICAO airport identifier and outputs a raw METAR string.  The `metar-decode` option takes the same input but provides decoded output.  The `metar-debug` option takes a METAR string and provides decoded output.

### What doesn't work ###

    av.pl taf ICAO-code

Needs to be updated to use the NOAA datasource that the METAR code uses.

    av.pl metar-detail ICAO-code

This provides decoded METAR data with airport information.  The METAR portion works, the airport portion does not.

   av.pl airport ICAO-code
   av.pl navaid Navaid-name/id

These were written to scrape HTML returned from airnav.com and have not been updated to work with the current airnav website.

#! /usr/bin/perl -w
# Copyright 2014, Casey Webster

package aviation;

my $no_metar;

BEGIN {
  eval "use LWP::UserAgent";
  if ($@) { $no_metar++};
  eval "use HTTP::Request";
  if ($@) { $no_metar++};
  eval "use HTTP::Response";
  if ($@) { $no_metar++};
  eval "use Time::Local"; 
  if ($@) { $no_metar++};
  eval "use POSIX qw(strftime)";
  if ($@) { $no_metar++};
}

sub aviation::metar::decode {
  my $metar = shift;
  $metar =~ s/METAR (.*?)=/\1/;
  my @tokens = split(/ /, $metar);
  my $x = shift;
  unless ($x) { $x = "\n"; }
  my $rmk = 0;
  my $stage = 0;
  my @unk = ();
  my @unkrmk = ();
  my %wdesc = (
	"MI" => "Shallow",
	"PR" => "Partial",
	"BC" => "Patches of",
	"DR" => "Low Drifting",
	"BL" => "Blowing",
	"SH" => "Showering",
	"TS" => "Thunderstorm",
  "PL" => "Pellets",
	"FZ" => "Freezing"
  );
  my %wphen = (
	"DZ" => "Drizzle",
	"RA" => "Rain",
	"SN" => "Snow",
	"SNPL" => "Snow with Ice Pellets", #this is a hack
	"SG" => "Snow Grains",
	"IC" => "Ice Crystals",
	"PE" => "Ice Pellets",
	"GR" => "Hail",
	"GS" => "Small Hail",
	"UP" => "Unknown",
	"BR" => "Mist",
	"FG" => "Fog",
	"FU" => "Smoke",
	"VA" => "Volcanic Ash",
	"DU" => "Widespread Dust",
	"SA" => "Sand",
	"HZ" => "Haze",
	"PY" => "Spray",
	"PO" => "Well Developed Dust/Sand Whirls",  
	"SQ" => "Squalls",
	"FC" => "Funnel Cloud",
	"SS" => "Sandstorm",
	"DS" => "Duststorm",
  "PL" => "Ice Pellets",
	"TS" => "Thunderstorm"   ## not in spec, but for TSB(hh)mmE(hh)mm
  );
  my %cloud = (
	"CLR" => "Clear Skies",
	"SKC" => "Clear Skies",
        "FEW" => "Few clouds", 
        "SCT" => "Scattered clouds", 
        "BKN" => "Broken clouds", 
        "OVC" => "Overcast", 
	"VV"  => "Vertical Visibility"
  );
  my %maint = (
	"RVRNO" => "RVR should be reported but is missing",
	"PWINO" => "Present weather identification sensor is not operating",
	"PNO"   => "Rain gauge is not operating",
	"FZRANO" => "Freezing rain sensor is not operating",
	"TSNO"  => "Lightning detection system is not operating",
	"VISNO" => "Secondary visibility sensor in not operating",
	"CHINO" => "Secondaty ceiling height sensor is not operating"
  );
  my $wdesc_pat = join("|", keys(%wdesc));
  my $wphen_pat = join("|", keys(%wphen));
  my $cloud_pat = join("|", keys(%cloud));
  my $maint_pat = join("|", keys(%maint));
  my $rpt_hour = 0;
  my $rpt_type = "";
  my $ICAO = shift @tokens;
  my $rpt = "Reporting Station $ICAO$x";
  #foreach $it (@tokens) {
  while (defined($it = shift(@tokens))) {

     ## Valid time
     if ($it =~ /(\d\d)(\d\d)(\d\d)Z/) {
       $time = timegm(0, $3, $2, $1, (gmtime)[4], (gmtime)[5]);
       $rpt_hour = $2;
       if ($rpt_hour =~ /(03|09|15|21)/) { $rpt_type = "3 Hour"; }
       #elsif ($rpt_hour =~ /(00|06|12|18)/) { $rpt_type = "6 Hour"; }
       else { $rpt_type = "6 Hour"; }
       $rpt .= "Report generated on ";
       $rpt .= &strftime("%b %e %I:%M %p %Y (%z)",localtime($time)) . $x;
       $stage = 1; ## Time Done
       next; 
     } 

     ## AUTO
     if ($it =~ /^AUTO$/) {
       $rpt .= "This report was generated automatically, no human intervention$x";
       next;
     }

     ## COR
     if ($it =~ /^COR$/) {
       $rpt .= "This report was corrected manually after being generated$x";
       next;
     }

     ## Wind
     if ($it =~ /([\dVRB]{3})(\d\d)G?(\d\d)?KT/) {
       my $d = $1;
       my $wk = $2;
       my $gk = $3 if $3;
       my $wm = $wk * 1.15;
       my $gm = $gk * 1.15 if $gk;
       if ($d =~ /000/ && $wk =~ /00/) { $rpt .= "Wind calm$x"; next; }
       $wk =~ s/^0+(.*)/$1/g;
       if ($d =~ /VRB/) { $rpt .= "Wind variable at $wk knots ($wm mph)"; next; }
       else { $rpt .= "Wind from $d degrees at $wk knots ($wm mph)"; }
       if ($gk) { $gk =~ s/^0+(.*)/$1/g; $rpt .= " with gusts to $gk knots ($gm mph)"; }
       $rpt .= "$x";
       $stage = 2; ## Time Done
       next;
     }

     ## Visiblility
     if ($it =~ /(M)?([\d\/ ]+)(SM|KM)/) {
       $rpt .= "Visibility";
       $rpt .= " less than" if $1;
       $rpt .= " $2 ";
       if ($3 =~ /SM/) { $rpt .= "statue miles$x"; }
       else { $rpt .= "kilometers$x"; }
       $stage = 3; ## Vis Done
       next;
     }

     ## Runway Visible Range (RVR)
     if ($it =~ /R(\d{2,3})(L|C|R|W)?\/(M|P)?(\d{4})(V)?(M|P)?(\d{4})?FT/) {
       my $rwy = $1;
       my $rwy_dsg = $2;
       my $rvr1 = $4;
       my $rvr1_mod = $3;
       my $rvr_var = $5;
       my $rvr2 = $7;
       my $rvr2_mod = $6;
       %rvr_mod = ( M => "less than ", P => "more than " );
       $rpt .= "Runway Visible Range for runway $rwy$rwy_dsg is ";
       if ($rvr_var) { $rpt .= "variable from "; }
       if ($rvr1_mod) { $rpt .= $rvr_mod{$rvr1_mod}; }
       $rpt .= "$rvr1 ft";
       if ($rvr_var) {
         $rpt .= " to ";
         if ($rvr2_mod) { $rpt .= $rvr_mod{$rvr2_mod}; }
         $rpt .= "$rvr2 ft";
       }
       $rpt .= $x;
       next;
     }
     
     ## Weather 
     if ($it =~ /^([-+])?(VC)?($wdesc_pat)?($wphen_pat)$/) {
       my $l = $1;
       my $v = $2;
       my $m = $3;
       my $t = $4;
       if (($l) && $l =~ /-/) { $rpt .= "Light "; }
       elsif (($l) && $l =~ /\+/) { $rpt .= "Heavy "; }
       else { $rpt .= "Moderate "; }
       $rpt .= $wdesc{$m} . " " if $m;
       $rpt .= $wphen{$t};

       $rpt .= " conditions exist";
       if ($v) { $rpt .= " in vicinity of airport"; }
       $rpt .= $x;
       $stage = 4; ## Weather Done
       next;
     }
     
     ## Cloud Layers
     if ($it =~ /($cloud_pat)(\d{3})?/) {
       my $l = $1;
       my $c = $2 if $2;
       $c =~ s/^0+(.*)/$1/g if $c;
       $rpt .= $cloud{$l} . " at " . $c . "00 feet AGL$x";
       next;
     }

     ## Clear skies and visibility
     if ($it =~ /^CAVOK$/) {
       $rpt .= "Clear skies and unlimited visibility$x";
       next;
     }

     ## Temperature
     if ($it =~ /^(M)?(\d\d)\/(M)?(\d\d)$/) {
       my $tc = $2; if ($1) { $tc *= -1; }
       my $dc = $4; if ($3) { $dc *= -1; }
       my $tf = $tc * 1.8 + 32;
       my $df = $dc * 1.8 + 32;
       $rpt .= "Temperature $tf F ($tc C)$x";
       $rpt .= "Dew Point   $df F ($dc C)$x";
       $stage = 6; ## Temp Done
       next;
     }    

     ## Altimiter
     if ($it =~ /A(\d{2})(\d{2})/) {
       $rpt .= "Altimiter $1.$2 in Hg$x";
       $stage = 7; ## Alt Done
       next;
     } 

     ## Altimiter
     if ($it =~ /Q(\d{4})/) {
       $rpt .= "Altimiter $1 mb$x";
       $stage = 7; ## Alt Done
       next;
     } 

     ## Remarks follow
     if ($it =~ /RMK/) {
       $rmk = 1;
       $rpt .= "Remarks Follow$x";
       $stage = 8; ## Non-remark Done
       next;
     }

     ## Type of reporting station
     if ($it =~ /AO(\d)/) {
       $rpt .= "Automatic reporting station ";
       if ($1 =~ /1/) { $rpt .= "without "; } 
       if ($1 =~ /2/) { $rpt .= "with "; } 
       $rpt .= "precipition discrimination$x";
       next;
     }

     ## Peak Wind
     if ($it =~ /^PK$/) {
       if ($tokens[0] =~ /^WND$/) {
         my $wnd = shift @tokens; # WND
         $wnd = shift @tokens; # dddss/hhmm
         my ($d, $s, $h, $m) = ($wnd =~ /(\d{3})(\d{2,3})\/(\d{2})(\d{2})/);
         my $sm = $s * 1.15;
         $rpt .= "Peak wind from $d deg at $s knots ($sm mph) occured at ";
         $rpt .= strftime("%I:%M %p (%z)",localtime(timegm(0, $m, $h, (gmtime)[3,4,5]))) . $x;
         next;
       }
     }

     ## Tower Visibility
     if ($it =~ /^TWR$/) {
       if ($tokens[0] =~ /^VIS$/) {
         my $vis = shift @tokens; # VIS
         $vis = shift @tokens; # d
         $rpt .= "Tower reports visibility of $vis miles$x";
         next;
       }
     }

     ## weather begin/end times 
     if ($it =~ /^($wdesc_pat)?($wphen_pat)(B|E)\d\d/) {
       my $num=0;
       while ($it !~ /^$/ ) {
         if ($it =~ /^($wdesc_pat)?($wphen_pat)/) {
           if ($num == 0) { $num++ } else { $rpt .= "$x"; }
           $rpt .= $wdesc{$1} . " " if $1;
           $rpt .= $wphen{$2};
           $it =~ s/^($wdesc_pat)?($wphen_pat)(.*)/$3/;
         } elsif ($it =~ /^(B|E)(\d{2})?(\d{2})/) {
           my $be = $1;
           my $hr = $2;
           my $mn = $3;
           if ($be =~ /B/) { $rpt .= " began at "; } 
           elsif ($be =~ /E/) { $rpt .= " ended at "; } 
           if ($hr) { 
             my $time = timegm(0, $mn, $hr, (gmtime)[3,4,5]);
             $rpt .= strftime("%I:%M %p (%z)",localtime($time));
           } else { 
             my $time = timegm(0, $mn, $rpt_hour, (gmtime)[3,4,5]);
             $rpt .= strftime("%I:%M %p (%z)",localtime($time));
           } 
           $it =~ s/^(B|E)(\d{2})?(\d{2})(.*)/$4/;
         } else {
           $rpt .= "Error processing weather times$x";
           last;
         }
       }
       $rpt .= "$x";
       next;
     }  

     ## Sea Level Pressure
     if ($it =~ /^SLP(\d{2})(\d)/) {
       $rpt .= "Sea level barometric pressure is 10" . $1 . "." . $2 . " hPa$x";
       next;
     }

     ## No significant Weather
     if ($it =~ /^NOSIG$/) {
       $rpt .= "No significant weather to report$x";
       next;
     }

     ## Hourly Precipitation
     if ($it =~ /^P(\d{4})/) {
       if ($1 =~ /0000/) { $rpt .= "Trace "; }
       else {
         $1 =~ /(\d{2})(\d{2})/; 
         my $d = $1;
         my $f = $2;
         $d =~ s/0+(.*)/$1/g;
         $rpt .= "$d.$f inches ";
       }
       $rpt .= "precipitation in the last hour$x";
       next;
     }

     ## 3 and 6 Hour Precipitation
     if ($it =~ /^6([\d\/]{4})/) {
       $c = $1;
       if ($c =~ /0000/) { $rpt .= "Trace "; }
       elsif ($c =~ /\/\/\/\//) { $rpt .= "Indeterminate "; }
       else {
         $1 =~ /(\d{2})(\d{2})/; 
         my $d = $1;
         my $f = $2;
         $d =~ s/0+(.*)/$1/g;
         $rpt .= "$d.$f inches ";
       }
       $rpt .= "precipitation in the last ". $rpt_type . "s$x";
       next;
     }

     ## 24 Hour Precipitation
     if ($it =~ /^7([\d\/]{4})/) {
       $c = $1;
       if ($c =~ /0000/) { $rpt .= "Trace "; }
       elsif ($c =~ /\/\/\/\//) { $rpt .= "Indeterminate "; }
       else {
         $1 =~ /(\d{2})(\d{2})/; 
         my $d = $1;
         my $f = $2;
         $d =~ s/0+(.*)/$1/g;
         $rpt .= "$d.$f inches ";
       }
       $rpt .= "precipitation in the last 24 hours$x";
       next;
     }

     ## Temperature to tenths
     if ($it =~ /^T(\d)(\d\d)(\d)(\d)(\d\d)(\d)/) {
       my $tc = $2 + $3/10; if ($1) { $tc *= -1; }
       my $dc = $5 + $6/10; if ($4) { $dc *= -1; }
       my $tf = $tc * 1.8 + 32;
       my $df = $dc * 1.8 + 32;
       $rpt .= "Hourly Temperature $tf F ($tc C)$x";
       $rpt .= "Hourly Dew Point   $df F ($dc C)$x";
       next;
     }    

     ## 3/6 hour Max Temperature to tenths
     if ($it =~ /^1(\d)(\d\d)(\d)/) {
       my $tc = $2 + $3/10; if ($1) { $tc *= -1; }
       my $tf = $tc * 1.8 + 32;
       $rpt .= "$rpt_type Max Temperature $tf F ($tc C)$x";
       next;
     }    

     ## 3/6 hour Min Temperature to tenths
     if ($it =~ /^2(\d)(\d\d)(\d)/) {
       my $tc = $2 + $3/10; if ($1) { $tc *= -1; }
       my $tf = $tc * 1.8 + 32;
       $rpt .= "$rpt_type Min Temperature $tf F ($tc C)$x";
       next;
     }    
     
     ## 3 hour pressure tendancy
     if ($it =~ /^5(\d)(\d{2})(\d)/) {
       my $ch = $2 + $3/10;
       my $t = $1;
       my $a = "";
       my $b = "";
       $rpt .= "Pressure ";
       if ($t =~ /0/) { $a = "same as or higher than"; $b = "and decreasing"; }
       if ($t =~ /1/) { $a = "higher than"; $b = "stabilizing"; }
       if ($t =~ /2/) { $a = "higher than"; $b = "increasing steady"; }
       if ($t =~ /3/) { $a = "higher than"; $b = "increasing rapidly"; }
       if ($t =~ /4/) { $a = "same as"; $b = "steady "; }
       if ($t =~ /5/) { $a = "same as or lower than"; $b = "increasing"; }
       if ($t =~ /6/) { $a = "lower than"; $b = "stablizing"; }
       if ($t =~ /7/) { $a = "lower than"; $b = "decreasing steady"; }
       if ($t =~ /8/) { $a = "lower than"; $b = "decreasing rapidly"; }
       if ($b =~ /decreasing/) { $ch *= -1; }
       $rpt .= "$a 3 hrs ago and $b with a net change of $ch hPa$x"; 
       next;
     }

     ## 24 hour max and min Temperature to tenths
     if ($it =~ /^4(\d)(\d\d)(\d)(\d)(\d\d)(\d)/) {
       my $tM = $2 + $3/10; if ($1) { $tM *= -1; }
       my $tm = $5 + $6/10; if ($4) { $tm *= -1; }
       my $tF = $tM * 1.8 + 32;
       my $tf = $tm * 1.8 + 32;
       $rpt .= "24 Hour Max Temperature $tF F ($tM C)$x";
       $rpt .= "24 Hour Min Temperature $tf F ($tm C)$x";
       next;
     }    

     ## Sensor Status Indicators
     if ($it =~ /^($maint_pat)$/) {
       $rpt .= $maint{$1};
       if ($it =~ /(VISNO|CHINO)/) {
         $it = shift @tokens;
         $rpt .= " at $it";
       }
       $rpt .= "$x";
       next;
     }

     ## Maintenance Indicator
     if ($it =~ /^\$$/) {
       $rpt .= "Automated systems dtect that maintenance is needed$x";
       next;
     }

     ## if we made it here, coded data is unknown, or just not coded for.
     if ($rmk) {
        push(@unkrmk, $it);
     } else {
        if (($stage == 2) && $it =~/^(\d{3})V(\d{3})$/) {
          $rpt .= "Variable wind from $1 to $2 degrees$x";
          next;
        } elsif (($stage == 2) && $it =~ /\d{4}/) {
          $rpt .= "Visibility $it meters$x";
        } elsif (($stage == 2) && $it =~ /^\d$/) {
          my $tmp = shift(@tokens);
          $it .= " $tmp";
          splice(@tokens, 0, 0, $it);
          next;
        } else {
          push(@unk, $it);
        }
     }
  }
  if ($unk[0]) { $rpt .= "Unknown data: " . join(" ", @unk) . "$x"; }
  if ($unkrmk[0]) { $rpt .= "Unknown remarks: " . join(" ", @unkrmk) . "$x"; }
  $rpt .= "\n";
  return $rpt;
}

sub aviation::metar::get {
   $ICAO = shift;
   if ($no_metar) {
     &status("METAR function requires LWP::UserAgent, HTTP::UserAgent and HTTP:Response and Time::Local");
     return '';
   }
   if ($ICAO !~ /^[A-Za-z0-9]{3,5}$/) {
      return "$ICAO does not appear to be a valid identifier";
   }
   my $ua = LWP::UserAgent->new();
   $ua->agent("InfoBot Custom Metar grabber/0.1");
   my $content="";
   my $metar="";
   my $metar_url = "http://weather.aero/dataserver_current/httpparam?dataSource=metars&requestType=retrieve&stationString=$ICAO&mostRecent=true&hoursBeforeNow=2";
   my $req = HTTP::Request->new(GET => $metar_url);
   my $response = $ua->request($req);
   if ($response->is_error()) {
     return "Error fetching METAR: $response->status_line\n";
   }
   $content = $response->as_string();
 
   $content =~ m/($ICAO.*)/;
   $metar = $1;

   $metar =~ s/[<&].*?[>;]/ /g;

   $metar =~ s/\s+/ /g;
   $metar =~ s/\n/ /s;

   if (length($metar) < 10) {
     return "$ICAO does not appear to be a valid metar station identifer\n";
   }

   return $metar;
}

sub aviation::metar::detail {
  my $ICAO = shift;
  #print "getting metar...";
  my $metar = &aviation::metar::get($ICAO);
  #print "decoding metar...";
  my $mreport = &aviation::metar::decode($metar);
  #print "getting airport...";
  my $areport = &aviation::airport($ICAO);
  #print "done\n";
  my $rpt = "";

  my $msl = 0;
  my $apt = "";
  my $mag = 0;

  my @lines = split("\n", $mreport);
  my @alines = split("\n", $areport);

  $apt = shift(@alines);
  while (defined($tok = shift(@alines))) {
    if ($tok =~ /Elevation: (\d+) ft/) { $msl = $1; }
    elsif ($tok =~ /Magnetic Variation: (\d+) deg (East|West)/) {
       my $dir = $2;
       $mag = $1;
       if ($dir =~ /West/) { $mag *= -1; }
    }
  }

  while (defined($tok = shift(@lines))) {
    if ($tok =~ /(Reporting Station .*)/) {
       $rpt .= $1 . " ($apt)\n";
    } elsif ($tok =~ /^(.*) (\d+) (feet AGL)/) {
       $rpt .= "$1 $2 $3 (" . ($2 + $msl) . " feet MSL)\n";
    } elsif ($tok =~ /^(.*) (\d+) (degrees|deg) (.*)/) {
       my $dir = $2 + $mag; if ($dir > 360) { $dir -= 360; }
       $rpt .= "$1 $2 $3 (" . ($dir) . " $3 mag) $4\n";
    } else {
       $rpt .= $tok . "\n";
    }
  }
  return $rpt
}

sub aviation::metar::get_forker {
   return '' if $no_metar;
   my ($ICAO, $decode, $callback) = @_;
   $SIG{CHLD} = 'IGNORE';
   my $pid = eval { fork() };
   return if $pid;
   my $mtr = &aviation::metar::get($ICAO);
   $callback->($mtr);
   if ($decode == 1) {
      my $rpt = &aviation::metar::decode($mtr);
      my @tok = split(/\n/, $rpt);
      foreach $itr (@tok) { $callback->($itr); }
   }
   exit 0 if defined $pid;
}

sub aviation::metar::detail_forker {
   return '' if $no_metar;
   my ($ICAO, $callback) = @_;
   $SIG{CHLD} = 'IGNORE';
   my $pid = eval { fork() };
   return if $pid;
   my $mtr = &aviation::metar::get($ICAO);
   $callback->($mtr);
   my $rpt = &aviation::metar::detail($ICAO);
   my @tok = split(/\n/, $rpt);
   foreach $itr (@tok) { $callback->($itr); }
   exit 0 if defined $pid;
}

sub aviation::taf::get {
   $ICAO = shift;
   if ($no_metar) {
     &status("TAF function requires LWP::UserAgent, HTTP::UserAgent and HTTP:Response and Time::Local");
     return '';
   }
   if ($ICAO !~ /^[A-Za-z0-9]{3,5}$/) {
      return "$ICAO does not appear to be a valid identifier";
   }
   my $taf_url = "http://www.dtn.com/aopa/metrpt.cfm";
   my $ua = LWP::UserAgent->new();
   $ua->agent("InfoBot Custom Metar grabber/0.1");
   my $req = HTTP::Request->new(POST => $taf_url);
   $req->content_type('application/x-www-form-urlencoded');
   $req->content("metbox=&tafbox=TAF&stateselect=++&city1=$ICAO&city2=&city3=&city4=&city5=&city6=&city7=&city8=&city9=&city10=&city11=&city12=");
   my $response = $ua->request($req);

   if ($response->is_error()) {
     return "Error fetching METAR: $response->status_line\n";
   }

   my $content = $response->as_string();
   $content =~ m/.*?TAFs for $ICAO.*($ICAO.*=).*/s;
   my $taf = $1;
   $taf =~ s/[<&].*?[>;]/ /g;
   $taf =~ s/\s+/ /g;
   $taf =~ s/\n/ /s;
   if (length($taf) < 10) {
     return "$ICAO does not appear to be a valid metar station identifer\n";
   }
   $taf = "TAF " . $taf;
   return $taf;
}

sub aviation::taf::get_forker {
   return '' if $no_metar;
   my ($ICAO, $callback) = @_;
   $SIG{CHLD} = 'IGNORE';
   my $pid = eval { fork() };
   return if $pid;
   my $mtr = &aviation::taf::get($ICAO);
   $callback->($mtr);
   exit 0 if defined $pid;
}

sub aviation::airport_forker {
   return '' if $no_metar;
   my ($ICAO, $callback) = @_;
   $SIG{CHLD} = 'IGNORE';
   my $pid = eval { fork() };
   return if $pid;
   my $rpt = &aviation::airport($ICAO);
   my @tok = split(/\n/, $rpt);
   foreach $itr (@tok) { $callback->($itr); }
   exit 0 if defined $pid;
}

sub aviation::airport {
   my $ICAO = shift;
   my $x = shift;
   unless ($x) { $x = "\n"; }
   if ($no_metar) {
        &status("METAR function requires LWP::UserAgent, HTTP::UserAgent and HTTP:Response and Time::Local");
        return '';
   }
   $ICAO = uc($ICAO);
   if ($ICAO !~ /^([A-Z0-9]{3,5})$/) {
       return "that doesn't look like a valid ICAO/FAA code: $line";
   }
   my $url = "http://www.airnav.com/airports/get?s=$ICAO";
   my $content = `lynx -dump "$url"`;
   my $rpt = "";
   my $elv = 0;
   my $id = 0;
   my @lines = split(/\n/, $content);
   
   while (defined($tok = shift(@lines))) { 
      #print $tok; 

      if ($tok =~ /^([A-Z0-9]{3,4} .*)/s) {
         if ($id > 0) { next; }
         $id++;
         $rpt .= "$1$x" if $1;
         $tok = shift @lines;
         $tok = shift @lines;
         $rpt .= "$tok$x" if $1;
         next;
      } elsif ($tok =~ /Lat\/Long: (.*)/s) {
	 $rpt .= "Coordinates: $1$x";
	 next;
      } elsif ($tok =~ /Elevation: (\d.*?)$/s) {
         if ($elv > 0) { next; }
         $rpt .= "Elevation: $1$x" if $1;
         $elv++;
         next;
      } elsif ($tok =~ /Variation: (\d+)(E|W).*?$/s) {
         my $d = $1;
         if ($2 =~ /E/) { $e = "East"; } else { $e = "West"; }
         $d =~ s/^0+(.*)/$1/g;
         $rpt .= "Magnetic Variation: $d deg $e$x";
         next;
      } elsif ($tok =~ /From city: (.*?)$/s) {
         $rpt .= "Location: $1$x";
         next;
      } elsif ($tok =~ /Sectional chart: (.*?)$/s) {
         my $c = $1;
         $c =~ s/(.*?)\[.*/$1/;
         $rpt .= "Sectional Chart: $c$x";
         next;
      } elsif ($tok =~ /ARTCC: (.*)$/s) {
         $rpt .= "ARTCC: $1$x";
         next;
      } elsif ($tok =~ /FSS: (.*?)$/s) {
         $rpt .= "FSS: $1$x";
         next;
      } elsif ($tok =~ /Use: (.*?)$/s) {
         $rpt .= "Use: $1$x";
         next;
      } elsif ($tok =~ /Runway (\d+(:?L|R|C)?\/\d+(:?L|R|C)?)$/s) {
         $rpt .= "Runway: $1$x";
         next;
      } elsif ($tok =~ /Surface: (.*?)$/s) {
         $rpt .= "$1$x";
         next;
      } elsif ($tok =~ /Dimensions: ([\d,]+ x [\d]+ ft).*?$/s) {
         $rpt .= "$1$x";
         next;
      }
   } 
   return $rpt;
}

sub aviation::navaid_forker {
   return '' if $no_metar;
   my ($NAVAID, $callback) = @_;
   $SIG{CHLD} = 'IGNORE';
   my $pid = eval { fork() };
   return if $pid;
   my $rpt = &aviation::navaid($ICAO);
   my @tok = split(/\n/, $rpt);
   foreach $itr (@tok) { $callback->($itr); }
   exit 0 if defined $pid;
}

sub aviation::navaid {
   my $NAVAID = shift;
   my $x = shift;
   unless ($x) { $x = "\n"; }
   if ($no_metar) {
        &status("METAR function requires LWP::UserAgent, HTTP::UserAgent and HTTP:Response and Time::Local");
        return '';
   }
   my $url = "http://www.airnav.com/cgi-bin/navaid-info?a=$NAVAID";
   my $content = `lynx -dump "$url"`;
   my $rpt = "";
   my @lines = split(/\n/, $content);

   while (defined($tok = shift(@lines))) { 

      if ($tok =~ /^\s\s\s$NAVAID$/) {
        $tok =~ s/\s*(.*)\s*/$1/g;
        $rpt .= "Name: $tok$x";
        $tok = shift @lines;
        $tok =~ s/\s*(.*)\s*/$1/g;
        $rpt .= "Long name: $tok$x";
        $tok = shift @lines;
        $tok =~ s/\s*(.*)\s*/$1/g;
        $rpt .= "Location: $tok$x";
        next;
      }
      if ($tok =~ /Lat\/Long: ([\d\.\s\/NEWS-]+)\(/) {
        $rpt .= "Coordinates: $1$x";
        next;
      }
      if ($tok =~ /Elevation: (\d+ ft)/) {
        $rpt .= "Elevation: $1$x";
        next;
      }
      if ($tok =~ /Variation: (\d+)(E|W).*/) {
        my ($v, $d) = ($1, $2);
        $v =~ s/^0+(.*?)/$1/g;
        if ($d =~ /W/) { $rpt .= "Magnetic Variation: $v deg West$x"; }
        elsif ($d =~ /E/) { $rpt .= "Magnetic Variation: $v deg East$x"; }
        next;
      }
      if ($tok =~ /Type: (.*)/) {
        $rpt .= "Navaid type: $1$x";
        next;
      }
      if ($tok =~ /Frequency: (.*)/) {
        $rpt .= "Frequency: $1$x";
        next;
      }
      if ($tok =~ /Altitude code: (.*)/) {
        $rpt .= "Altitude: $1$x";
        next;
      }
      if ($tok =~ /Morse ID: (.*)/) {
        $rpt .= "Identifier: $1$x";
        next;
      }
   }
   return $rpt;
}

;;
1

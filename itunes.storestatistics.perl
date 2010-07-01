#!/usr/bin/perl
#

use strict;

my $collecthours = 0;
my $interestingprogram = undef;


if( $ARGV[0] =~ m/hours/ )
{
	$collecthours = 1;
	shift @ARGV;
}

if( $ARGV[0] !~ m/\./ )
{
	$interestingprogram = shift @ARGV;
}

my %statistichash;
my %pricehash;




if( $interestingprogram )
{
	print join("\t",('Country','Category','Paid','Programid','Programname','Date','Rank','Price'))."\n";
}

my $filecounter = 0;
my %interestingprogramcache = undef;

foreach my $filename (sort @ARGV)
{
#	print STDERR $filename."\n";
	if( $filename =~ /itunesoutput\.([^\.]+)\.([^\.]+)\.([^\.]+)\.([^\.]+)\.([^\.]+)(\.gz)?$/ )
	{
		# print STDERR "Reading file $filename\n";
		
		my( $country, $category, $paid, $originaldate, $originaltime, $gzip ) = ( $1, $2 ,$3, $4, $5 ,$6 );
		
		my $dateandtime = $originaldate;
		$dateandtime.=$originaltime if $collecthours;
		
		my( $date, $time ) = ( $originaldate, $originaltime );
		$time =~ s/(\d\d)(\d\d)(\d\d)/$1:$2/;
		$date =~ s/(\d\d)(\d\d)(\d\d)(\d\d)/$4\/$3\/$2/;
		my $file;
		
		$filename = 'gzip -d <'.$filename.'|' if length($gzip);
		open($file,$filename) || next;
		$filecounter++;
		my $place = 0;	

		$time = '' if !$collecthours;

		my $interestingprogramprinted = 0;
		
		while( my $line = <$file> )
		{
			if( $line =~ /<Buy\s([^>]+)>/o )
			{
				my $buytag = $1;
				
				if( $buytag =~ /salableAdamId=(\d+)(?:&amp;|").*price=(\d+)(?:&amp;|").*itemName="([^\"]+)"/o )
				{
					my( $programid, $programname, $price ) = ($1,$3,$2);
					
					$price = sprintf "%5.2f",$price/100.0;
					$place++;
					
					if( $filecounter >1 && $place < 10 &&  !defined($statistichash{programs}{$programid}{bestplace}) )
					{
						printf STDERR "%10s Program %20s (%10s) cheating ?  price: %10s %5.2f (place:%2d)\n",$country,$programname,$programid,$date.' '.$time,$price,$place;
					}
					
					if( defined $pricehash{$programid}{$country} && $price != $pricehash{$programid}{$country} )
					{
					#	printf STDERR "Name %s %s %s\n",$programname,$programid,$price;
					#	printf STDERR $line;
						printf STDERR "%10s Program %20s (%10s) switched price: %10s %5.2f -> %5.2f (place:%2d)\n",$country,$programname,$programid,$date.' '.$time,$pricehash{$programid}{$country},$price,$place;
					}
					$pricehash{$programid}{$country}=$price+0;
					
					#$statistichash{$country}{$category}{$programname}{$date.' '.$time}{price}=$price/10.0;
					
					$statistichash{dates}{$dateandtime} 								= $date.' '.$time;
					$statistichash{programs}{$programid}{info}{$dateandtime}{place}		= $place;
					$statistichash{programs}{$programid}{name}							= $programname;
					
					if( !defined $statistichash{programs}{$programid}{bestplace} ||	$statistichash{programs}{$programid}{bestplace} > $place )
					{
						$statistichash{programs}{$programid}{bestplace}	=$place;
					}
	
					if( $interestingprogram && (($programid eq $interestingprogram) || ($programname =~ /$interestingprogram/)) )
					{
						$interestingprogramprinted = 1;
						if( !defined %interestingprogramcache )
						{
							%interestingprogramcache 	= ( programid 	=>  $programid,
															paid		=>	$paid,
															programname	=>	$programname,
														);	
						}
						printf "%20s\t%10s\t%10s\t%10s\t%20s\t%10s %10s\t%2d\t%5.2f\n",$country,$category,$paid,$programid,$programname,$date,$time,$place,$price;
					}
				}
				else
				{
					print STDERR "Warning line did not parse correctly2: ".$line;
				}
			}
		}
		close($file);
		
		if( $interestingprogram && !$interestingprogramprinted && %interestingprogramcache)
		{
			printf "%20s\t%10s\t%10s\t%10s\t%20s\t%10s %10s\t\t\n",$country,$category,$interestingprogramcache{paid},$interestingprogramcache{programid},$interestingprogramcache{programname},$date,$time;
		}

		
		
	}
}

if( $interestingprogram )
{
	exit;
}


#
# print header
#

my @programarray = sort { $statistichash{programs}{$a}{bestplace} <=> $statistichash{programs}{$b}{bestplace} } (keys %{$statistichash{programs}});


print "Date";
for my $programid  (@programarray)
{
	print "\t".$statistichash{programs}{$programid}{name};
}
print "\n";

#
# print the dates
#

for my $dateandtime ( sort keys %{$statistichash{dates}} )
{
	print $statistichash{dates}{$dateandtime} ;
	for my $programid (@programarray)
	{
		if( defined $statistichash{programs}{$programid}{info}{$dateandtime}{place} )
		{	
		#	print "\t".(101.0- ($statistichash{programs}{$programid}{info}{$dateandtime}{place}));
			print "\t".($statistichash{programs}{$programid}{info}{$dateandtime}{place});
		}
		else
		{
			print "\t";
		}
	}
	print "\n";
}


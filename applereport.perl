#!/usr/bin/perl

# author: jolly
#
# usage: perl applereport.perl S_D* |open -f -a Numbers


use Time::Local;
use POSIX;
use LWP::UserAgent;

use strict;

my %conversiontable = (	'EUR'	=>	1.0 ,
						'CAD'	=>	0.62,
						'USD'	=>	0.78,
						'GBP'	=>	1.16,
						'JPY'	=>	0.0083044929,
						'AUD'	=>	0.516179095,
						);

my %googlenames =	(	'EUR'	=>	'Euro',
						'CAD'	=>	'Canadian dollar',
						'USD'	=>	'U.S. dollar',
						'GBP'	=>	'British pound',
						'JPY'	=>	'Japanese yen',
						'AUD'	=>	'Australian dollar',
						);
						
{
	foreach my $currency (keys(%conversiontable))
	{
		next if $currency eq 'EUR';
	
		my $userAgent	= LWP::UserAgent->new;
		
		$userAgent->agent("JNXAppleReporter/0.1 ");

		my $request		= HTTP::Request->new(GET => 'http://www.google.com/search?q='.$currency.'+to+EUR');
		my $response	= $userAgent->request($request);

		if( $response->is_success )
		{
			my $content		= $response->content();
			my $googlename	= $googlenames{$currency};
			
			if( $content =~ m/<b>\s*1\s*$googlename(?:s?)\s*=\s*(\d+\.\d+)\s*Euros?\s*<\/b>/ )
			{
				print "Overriding $currency\t$1\n";
				$conversiontable{$currency} = $1;
			}
		}
	}

}
						

						
my $argumentweekly = 0;

if( @ARGV[0] =~ m/weekly/ )
{
	shift @ARGV;
	$argumentweekly = 1;
	
	printf STDERR "USING WEEKLY OUTPUT\n";
	sleep(1);
}


my @interestingheaders = ('Units','Royalty Price', 'Country Code', 'Begin Date', 'End Date' );


my @headers;
my %table;
my %countries;
my %programname;


while( my $filename = shift @ARGV )
{
	my $usegzip = 0;
	
	$usegzip = 1 if $filename =~ /\.g(z|zip)$/;
	
	print STDERR "Opening: $filename\n";
	
	open(FILE,($usegzip?'gzip -d <'.$filename.'|':'<'.$filename)) || next;
	print STDERR "Reading: $filename\n";
	while( my $line = <FILE>)
	{
		chomp;
		
		if( $line !~/\d/ )						# if there are no numbers it's propably a header
		{
			@headers = split(/\t/,$line);
			# print "Headers: @headers\n";
		}
		else
		{
			my %row;
			@row{@headers} = (split(/\t/,$line));
			
			$row{'Begin Date'}=$3.$1.$2 if $row{'Begin Date'} =~ /(\d{2})\/(\d{2})\/(\d{4})/;

			if( $argumentweekly  && ($row{'Begin Date'} =~ /(\d{4})(\d{2})(\d{2})/) )
			{
				# printf STDERR "Does match :".$row{'Begin Date'}."\n";
				my($itmsyear,$itmsmonth,$timsday) = ($1,$2,$3);
				
				my $mytime = timegm(1,0,0,,$timsday,$itmsmonth-1,$itmsyear);
				
				my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($mytime);
				
				$mytime = $mytime - ( $wday * 86400 ) + 86400;
				
				$row{'Begin Date'} = POSIX::strftime("%Y%m%d",gmtime($mytime));
			}
	
			{
				
				my $currentdate		= $row{'Begin Date'};
				my $country			= $row{'Country Code'};
				my $programid		= $row{'SKU'};
				my $units			= $row{'Units'};
				my $royaltyprice	= $row{'Developer Proceeds'};
				my $royaltycurrency	= $row{'Currency of Proceeds'};
				
				my $conversionrate 	= $conversiontable{$royaltycurrency};
				
				my $earnings 		= 0.0;
	
				if( $conversionrate > 0.0 )
				{
					$earnings = $units * $conversionrate * $royaltyprice;
				}
				else
				{
					while( my($key,$value) = each(%row) )
					{
						printf STDERR "Key:%10s Value:%s\n",$key,$value;
					}
					die 'Conversion rate for '.$royaltycurrency." not known ($conversionrate)\n";
				}
				
				$programname{$programid} 								= $row{'Title'};
				$countries{$programid}{$country}						+= $earnings;
				$table{$currentdate}{$programid}{$country}{($royaltyprice>0?'units':'freeunits')}	+= $units;
				$table{$currentdate}{$programid}{$country}{earnings}	+= $earnings;
			}
		}
	}
	close(FILE);
}

my @dates 		= sort(keys %table);

my @weekdays;

foreach my $date (@dates)
{
	if( $date =~ /(\d{4})(\d{2})(\d{2})/ )
	{
		my($itmsyear,$itmsmonth,$timsday) = ($1,$2,$3);
		my $mytime = timegm(1,0,0,,$timsday,$itmsmonth-1,$itmsyear);				
		push(@weekdays,POSIX::strftime("%a",gmtime($mytime)));
	}
	elsif( $date =~ /(\d{2})\/(\d{2})\/(\d{4})/ )
	{
		my($itmsyear,$itmsmonth,$timsday) = ($3,$1,$2);
		my $mytime = timegm(1,0,0,,$timsday,$itmsmonth-1,$itmsyear);				
		push(@weekdays,POSIX::strftime("%a",gmtime($mytime)));
	}
	else
	{
		die "Can't figure out weekday: $date\n";
	}
}
my %weekdays;

@weekdays{@dates}=@weekdays;

my %sums;

for my $programid (sort(keys %countries))
{
	print "DoW\t".join("\t",@weekdays)."\n";
	print $programname{$programid}."\t".join("\t",@dates)."\n";
	
	my @allcountries = sort{ $countries{$programid}{$a} <=> $countries{$programid}{$b} }(keys %{$countries{$programid}});
	
	my @topcountries;
	if( @allcountries > 9 )
	{
		@topcountries 		= splice(@allcountries,-9);
		my $restofworldcountry 	= 'RoW';
		
		for my $country (@allcountries)
		{		
			for my $date (@dates)
			{	
				$table{$date}{$programid}{$restofworldcountry}{units}	 += $table{$date}{$programid}{$country}{units};
				$table{$date}{$programid}{$restofworldcountry}{earnings} += $table{$date}{$programid}{$country}{earnings};
				$table{$date}{$programid}{$restofworldcountry}{freeunits} += $table{$date}{$programid}{$country}{freeunits};
			}
		}
		
		splice(@topcountries,0,0,$restofworldcountry);
	}
	else
	{
		@topcountries = @allcountries;
	}
	
	for my $country (@topcountries)
	{
		print $country."\t";
		
		for my $date (@dates)
		{	
			print $table{$date}{$programid}{$country}{units}."\t";
			$sums{$programid}{$date}{units}		+= $table{$date}{$programid}{$country}{units};
			$sums{$programid}{$weekdays{$date}}	+= $table{$date}{$programid}{$country}{units};
			$sums{$programid}{'ALLDAYS'}		+= $table{$date}{$programid}{$country}{units};
			$sums{$programid}{$date}{earnings}	+= $table{$date}{$programid}{$country}{earnings};
			$sums{$programid}{$date}{freeunits}	+= $table{$date}{$programid}{$country}{freeunits};
		}
		print "\n";
	}
	
	foreach my $type ( 'units', 'earnings' ,'freeunits')
	{
		print 'SUM('.$type.")\t";
		
		for my $date (@dates)
		{	
			printf "%.2f\t",$sums{$programid}{$date}{$type};
		}
		print "\n";
	}
	print "\n";
	
	if( $sums{$programid}{'ALLDAYS'} > 0 )
	{
		foreach my $weekday ( 'Mon','Tue','Wed','Thu','Fri','Sat','Sun' )
		{
			printf "SUM(%s)\t%.2f\n",$weekday,100.0*$sums{$programid}{$weekday}/$sums{$programid}{'ALLDAYS'};
		}
	}
	print "\n\n";
}


print "\t".join("\t",@dates)."\n";
print "DoW\t".join("\t",@weekdays)."\n";

for my $programid (sort(keys %countries))
{
	
	print $programname{$programid}."\t";
		
	for my $date (@dates)
	{	
		printf "%.2f\t",$sums{$programid}{$date}{earnings};
	}
	print "\n";
}


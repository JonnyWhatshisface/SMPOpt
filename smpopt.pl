#!/usr/bin/perl
#
# Jonathan Hall (Jon@JonathanDavidHall.com)
#
# To say this is a bit messy is an understatement, but it works.
#
# This sceript helps to quickly identify which socket PCI devices
# are connected to on a given system, as well as give a quick
# overview of the CPU architecture and make a rough suggestion on
# smp affinity optimization to reduce latency and optimize interrupt
# performance by handling the hardware interaction on the local socket.
#
# The suggest and auto options are not meant to be perfect. They will only
# give an optimization that localizes all interrupts to the socket the PCI
# device is directly attached to. It does not mean it's the most optimal
# interrupt mapping for your use-case, but should be enough to get you started.
#
# Please remember that disabling irqbalance is required to take advantage of this,
# and once you've done so, you need to balance all devices in the system which
# can be balanced. You can identify those devices via the --adjustableonly option.
#
# The script can likewise be used to set the smp affinity via a string,
# formatted as follows with a delimeter of semicolon (;) between each entery.
#     - <device>@<cpu-list>:<method>
#
# Use --suggest to get a set string and you can quickly tweak from there.
#
# The Science Behind It...
#
# The PCI address space is 256 bytes, which is divided up amongst the count of active 
# sockets in the system. On a two (2) socket system, the address space would be 0x00-0x7F
# on socket 0 and 0x80-0x9F on socket 1. 
#
# This script requires you install the following CPAN modules:
#     - Getopt::Long
#     - Set::IntSpan::Fast
#
# TODO: 
#
# - Remove usage of lscpu
#
# - Remove usage of lspci, scan /sys/bus/pci/devices and parse /usr/share/misc/pci.ids
#
# - Add support for more than 2 threads per core (ie PPC SMT)
#
# - Bundle required libs in with the script so it's stand-alone
#
# - Identify locality to specific PCIe bridges (for SNC and XCC)
#

use warnings;
use Carp;
use Exporter;
use IO::File;
use Set::IntSpan::Fast;
use Getopt::Long;

use experimental 'switch';

my $invoked_as = $0;
my $lspci = "lspci";
my $pci_max_space = 256;
my (@space_map, @problem_devices);

my ($pcidevices, $type, %cpu_map, %interface_list, %known_interfaces, @devices, %device_matrix, %dev_map, %set_affinity_map, %irqmap);
my ($noconfirm, $auto, $scan, $reportonlyadjustable, $set, $checkprocintr, $showcpu, $showset, $showsharedirqs);
my ($suggest, $suggested_cmd_line, $cpuht, $cpucores, $threads_per_core, $cores_per_socket, $cpusockets, $debug, $dryrun);

GetOptions(
    "devices=s"             => \$pcidevices,
    "auto"                  => \$auto,
    "noconfirm"             => \$noconfirm,
    "scan"                  => \$scan,
    "adjustableonly"        => \$reportonlyadjustable,
    "suggest"               => \$suggest,
    "type=s"                => \$type,
    "set"                   => \$set,
    "showcpu"               => \$showcpu,
    "showsharedirqs"        => \$showsharedirqs,
    "checkintr"             => \$checkprocintr,
    "showset"               => \$showset,
    "debug=s"               => \$debug,
    "dryrun"                => \$dryrun,
) || &usage();

$device_matrix{'nic'} = "Ethernet controller";
$device_matrix{'nvme'} = "Non-Volatile memory controller";
$device_matrix{'raidctl'} = "RAID bus controller";
$device_matrix{'hba'} = "Fibre Channel";

my $verbose = 1;

sub usage {
    print "\nsmpopt 0.1 - Jonathan D. Hall <Jon\@JonathanDavidHall.com>\n\n";
    print "Example commands:\n\n";
    print "Scan out adjustable PCI devices and suggest an initial starting affinity set string:\n";
    print "     $invoked_as --scan --adjustableonly --suggest\n\n";
    print "Scan out all NIC's and show their affinity configuration:\n";
    print "     $invoked_as --scan --type nic\n\n";
    print "Scan specific PCI devices by their device address(es):\n";
    print "     $invoked_as --scan --devices \"00:01.00;00:07.00\"\n\n";
    print "Set IRQ affinity of specified devices to specified CPU's and distribution method:\n";
    print "     $invoked_as --set --devices \"00:07.0\@0,3-4,9:rr;00:07.1\@1-2,5-8,10:rr\" --noconfirm\n\n";
    print "Options:\n\n";
    print "     --scan                      Scan PCI devices. Optional arguments:\n";
    print "         --adjustableonly        Show only devices that can have SMP affinity adjusted\n";
    print "         --checkintr             Use /proc/interrupts to gather interrupt data\n";
    print "         --devices               PCI device ID's to check, separated by semi-colon (;)\n";
    print "         --showsharedirqs        Show IRQ handlers that are shared and the devices sharing them\n";
    print "         --suggest               Suggest an initial affinity (may still require further tweaking)\n";
    print "         --type                  Scan specified device types. Available types: nic,nvme,raidctl,hba\n\n";
    print "     --set                       Set IRQ Affinity. Requires one of the following:\n";
    print "         --devices               Formatted as: \"<pci_dev>\@<cpus>:<method>\" separated with semi-colon (;)\n";
    print "             <cpus>              Range and individual CPU's accepted, i.e.: 0,3,4-7,9,11\n";
    print "             <method>            There are three available distribution methods:\n";
    print "                                 rr  - One CPU per IRQ handler, rotated in an ascending order of specified CPU range\n";
    print "                                 rrr - One CPU per IRQ handler, rotated in an descending order of specified CPU range\n";
    print "                                 lst - Set the affinity on each IRQ handler exactly as specified (ie range)\n";
    print "         --auto                  Will automatically set everything to the suggested starting values\n\n";
    print "     --showcpu                   Only show CPU info\n\n";
    print "Debug, verbosity and confirmation override:\n\n";
    print "     --debug                     Show debug output\n";
    print "     --dryrun                    Don't do any set actions, just print what it would do\n";
    print "     --showset                   Print out each IRQ adjustment as set\n";
    print "     --noconfirm                 Don't prompt for confirmations and just silently set\n";

    print "\n";

    exit(0);
}

sub Main{
    &usage() unless $pcidevices || $auto || $scan || $showcpu;

    &GatherCPUInfo();

    if ($scan) {
        &ScanDevices();
        &PrintPCIDevInfo();
    }

    if ($set) {
        $verbose = 0;
        &HandleSets();
        # Had to do it twice due to previous bug...
        # May not be required anymore?
        #&HandleSets();
    }

}

sub PrintSharedIRQs {
    print "Checking for shared IRQ handlers...\n";

    foreach my $irqhandler (sort {$a<=>$b} keys %irqmap) {
        my $devicesonirq = @{$irqmap{$irqhandler}{'devices'}};
        if ($devicesonirq > 1) {
            print "    IRQ [$irqhandler] is shared by the following devices:\n";
            foreach (@{$irqmap{$irqhandler}{'devices'}}){
                print "        $_\n";
            }
            print "\n";
        }
    }
}

sub HandleSets {
    # Builds set_affinity_map
    #
    # Expects devid@cores:methos separated with ;
    # Example: 00:81:00.0@0-3,5,7:rr;00:83:00.0@0-5:rr
    #
    # devid:  The PCI bus ID of the device (i.e.: 00:8b:00.1)
    # cores:  CPU cores. Accepts ranges and individuals. (i.e.: 0-4,6,8,9-1)
    # method: Distribution method. Available methods are:
    #    rr    -    Round-Robin. Start with lowest to highest cyclically asigning IRQ handler to that CPU
    #   rrr    -    Round-Robin-Reverse. Same as rr method but in descending order
    #   lst    -    Assigns exactly as specified. If 0-4,6,9-11 - then each IRQ will be assiged 0-4,6,9-11
    #
    use feature "switch";

    my @sets = split(";", $pcidevices);
    foreach (@sets) {
        my @set = split("@", $_);
        my @set2 = split(":", $set[1]);
        my $devid = $set[0];
        my $corelist = $set2[0];
        my $distmethod = $set2[1];
        # Build the device map...
        &GetDevInfo($devid);
        &VerifySet($devid, $corelist) unless ($noconfirm);

        given ($distmethod) {
            when ("rr") {
                my @itercores;
                my $set = Set::IntSpan::Fast->new(join ",", $corelist);
                my $iterate = $set->iterate_runs;
                while (my($from, $to) = $iterate->()) {
                    for my $member($from..$to) {
                        push @itercores, $member;
                    }
                }
                my @usableirqs;
                if ($dev_map{$devid}{'usableirqs'}) {
                    foreach(sort {$a<=>$b} keys %{$dev_map{$devid}{'usableirqs'}}) {
                        push @usableirqs, $_;
                    }
                }
                # All cores now in @itercores
                my $corecount = @itercores;
                my $cur = 0;
                foreach(@usableirqs) {
                    $set_affinity_map{$_} = $itercores[$cur];
                    ++$cur;
                    $cur = 0 if ($cur > $corecount - 1);
                }
            }

            when ("rrr") {
                my @itercores;
                my $set = Set::IntSpan::Fast->new(join ",", $corelist);
                my $iterate = $set->iterate_runs;
                while (my($from, $to) = $iterate->()) {
                    for my $member($from..$to) {
                        push @itercores, $member;
                    }
                }
                my @usableirqs;
                if ($dev_map{$devid}{'usableirqs'}) {
                    foreach(sort {$a<=>$b} keys %{$dev_map{$devid}{'usableirqs'}}) {
                        push @usableirqs, $_;
                    }
                }
                # All cores in @itercores
                my $corecount = @itercores;
                my $cur = $corecount - 1;
                foreach(@usableirqs) {
                    $set_affinity_map{$_} = $itercores[$cur];
                    --$cur;
                    $cur = $corecount - 1 if ($cur < 0);
                }
            }

            when ("lst") {
                my @usableirqs;
                if ($dev_map{$devid}{'usableirqs'}) {
                    foreach(sort {$a<=>$b} keys %{$dev_map{$devid}{'usableirqs'}}) {
                        push @usableirqs, $_;
                    }
                }
                foreach(@usableirqs) {
                    $set_affinity_map{$_} = $corelist;
                }
            }

            default {
                die "Invalid affinity distribution method specified for [$devid] - Exiting!\n";
            }
        }
    }
    # Map is built. Now lets execute set
    &ExecuteAffinitySets();
}

sub VerifySet {
    # Verify the set is sane and prompt if not
}

sub ExecuteAffinitySets {
    # Perform the sets according to %set_affinity_map
    print "Setting affinity...\n" if ($showset);

    for my $irq (sort {$a<=>$b} keys %set_affinity_map) {
        my $value = $set_affinity_map{$irq};
        if (!$dryrun) {
            open(my $fh, '>', "/proc/irq/$irq/smp_affinity_list") or die("Unable to open /proc/irq/$irq/smp_affinity_list !\n");
            print "    $irq:$value\n" if ($showset);
            print $fh "$value";
            close $fh;
        }
        if ($dryrun) {
            print "Would set IRQ [$irq] to [$value]\n";
        }
    }
}

sub ScanDevices {
    my @types;
    if($type) {
        @types = split(',', $type);
    }
    if ($pcidevices) {
        @devices = split(';',$pcidevices);

        foreach(@devices) {
            if (!$scan) {
                die "You must specify devices if not using -auto!\n" if ($_ !~ /@/) && (!defined $auto);
                print "You must specify devices...\n";
            } else {
                die "Do not specify CPU affinity when scanning\n" if ($_ =~ /@/);
                &GetDevInfo($_);
            }
        }
    } else {
        my @all = qx#lspci -nn#;
        foreach(@all) {
            # check type
            my $cur = $_;
            if ($type) {
                foreach (@types) {
                    my $check = $device_matrix{$_};
                    die "Invalid type specified...\n" if (!$check);
                    if ($cur =~ /$check/) {
                        my @id = split(" ", $cur);
                        &GetDevInfo($id[0]);
                    }
                }
            } else {
                my @id = split(" ", $_);
                &GetDevInfo($id[0]);
            }
        }
    }
    print "\nPCI Devices Scanned: \n";
}

sub PrintPCIDevInfo {
    my @suggestions;
    print "\n";
    foreach (sort keys %dev_map) {
        my @devsuggested;
        my @irqs = split(",", $dev_map{$_}{'irqlist'});
        my $set = Set::IntSpan::Fast->new($dev_map{$_}{'irqlist'});
        my ($devid, $devproc, @shouldavoid);
        $devid = $_;
        $devproc = $dev_map{$_}{'processor'};
        my $finalirq;
        my $irqlist = $set->as_string;
        my ($flag_banned_cpu,$flag_not_usable);
        print"    $dev_map{$_}{'devname'}\n";
        print "        Device is on Processor [$devproc]\n";
        if ($dev_map{$_}{'irqcount'}) {
            # Identify devices using non-optimial cores for interrrupts
            print "        Device uses [$dev_map{$_}{'intrmode'}] for [$dev_map{$_}{'irqcount'}] IRQ handler(s): [$irqlist]\n";

            my @usableirqs;
            if ($dev_map{$_}{'usableirqs'}) {
                foreach(sort {$a<=>$b} keys %{$dev_map{$_}{'usableirqs'}}) {
                    push @usableirqs, $_;
                }
            }
            my $set = Set::IntSpan::Fast->new(join ",", @usableirqs);
            $finalirq = $set->as_string;
            $set = Set::IntSpan::Fast->new(join ",", $dev_map{$_}{'curaffinity'});
            my $irqaffinity = $set->as_string;
            my $iter = $set->iterate_runs;
            my @itercores;
            if ($finalirq) {
                print "        Device currently using IRQ handlers: [$finalirq]\n";
                print "        Device uses cores [$irqaffinity] for interrupts\n";
                # Iterate cores to verify whether there's cross qpi/upi affinity
                while (my ($from, $to) = $iter->()) {
                    for my $member ($from..$to) {
                        push @itercores, $member;
                    }
                }
                # Ensure they're all on the "usable" list and warn otherwise
                my $usablecores = $cpu_map{'sockets'}{$devproc}{'usable'};
                my $bannedcores = $cpu_map{'sockets'}{$devproc}{'banned'};
                my (%banned, %usable);
                foreach(sort {$a<=>$b} keys %$bannedcores) {
                    $banned{$_} = 1;
                }
                foreach(sort {$a<=>$b} keys %$usablecores) {
                    $usable{$_} = 1;
                    push @devsuggested, $_;
                }
                foreach (@itercores) {
                    my $curcore = $_;
                    $flag_not_usable = 1 if !$usable{$_};
                    $flag_banned_cpu = 1 if $banned{$_};
                }
                if ($flag_banned_cpu || $flag_not_usable) {
                    push @problem_devices, $devid;
                    print "            *** [NOTICE] *** Device affinity appears to be nonoptimal! *** [NOTICE] ***\n" if ($flag_not_usable) && (!$checkprocintr);
                    print "            *** [WARNING] *** HT logicals handling interrupts - this is nonoptimal! *** [WARNING] ***\n" if ($flag_banned_cpu) && (!$checkprocintr);
                    print "            *** [WARNING] *** /proc/interrupts shows interrupts have been performed on nonoptimal cores! *** [WARNING] ***\n" if ($flag_not_usable) && ($checkprocintr);
                    print "            *** [WARNING] *** /proc/interripts shows interrupts performed on logical HT cores! *** [WARNING] ***\n" if ($flag_banned_cpu) && ($checkprocintr);
                }
            } else {
                print "        Device has no interrupt handlers...\n";
            }
        }
        # Device driver...
        if ($dev_map{$_}{'driver'}) {
            # Check if version is there, too
            print "        Device uses driver [$dev_map{$_}{'driver'}] version [$dev_map{$_}{'driver_version'}]\n" if ($dev_map{$_}{'driver_version'});
            print "        Device uses driver [$dev_map{$_}{'driver'}]\n" if (!$dev_map{$_}{'driver_version'});
        }

        if ($suggest && $finalirq) {
            my $set = Set::IntSpan::Fast->new(join ",", @devsuggested);
            my $sug = $set->as_string;
            print "    Suggested Affinity: [$sug]\n";
            print "    Note: This is just a rough suggestion. Further optimization may likely need to be done...\n";
            push @suggestions, "$devid\@$sug:rr";
        }
        print "\n";
    }

    print "Devices that affinity should be looked at:\n";
    foreach(@problem_devices) {
        print "    $dev_map{$_}{'devname'}\n";
    }

    print "\n";

    if ($showsharedirqs) {
        &PrintSharedIRQs();
    }

    if ($suggest) {
        print "\nSuggested -set commandline for basline performance adjustment:\n\n";
        print "   $invoked_as --set --devices \"" . join(";", @suggestions) . "\" --noconfirm\n";
    }

    print "\n";
    
}

sub GatherCPUInfo {
    # Build a topology macp by reading from /sys/devices/system/cpu
    my $topology_item;
    &Output("\nGathering CPU info...\n");

    # Re-write this and get rid of lscpu usage entirely
    chomp($cpucores = qx#/usr/bin/lscpu | grep "^CPU(s):" | awk '{print \$2}'#);
    chomp($threads_per_core = qx#/usr/bin/lscpu | grep "^Thread(s) per core:" | awk '{print \$4}'#);
    chomp($cores_per_socket = qx#/usr/bin/lscpu | grep "^Core(s) per socket:" | awk '{print \$4}'#);

    $cpuht = "1" if ($threads_per_core > 1);

    opendir (my $topo_fh, "/sys/devices/system/cpu");
    while (my $entry = readdir $topo_fh) {
        next unless $entry =~ /^cpu\d+/;
        my $logical_id = substr($entry, 3);
        my $topology = "/sys/devices/system/cpu/$entry/topology";
        open($topology_item, '<:encoding(UTF-8)', "$topology/physical_package_id");
        chomp(my $package = <$topology_item>);
        close $topology_item;
        open($topology_item, '<:encoding(UTF-8)', "$topology/thread_siblings_list");
        chomp(my $core_siblings = <$topology_item>);
        close $topology_item;

        $cpu_map{'packages'}{$package}{$logical_id} = $core_siblings;
    }

    # Iterate package count to get socket count
    $cpusockets = keys %{$cpu_map{'packages'}};

    &Output("    System has [$cpusockets] processors @ [$cores_per_socket] cores per processor...\n");
    &Output("    Total seen CPU's including logicals: [$cpucores]\n");
    &Output("    SMT detected @ [$threads_per_core] threads per physical core...\n") if ($cpuht);
    &Output("    SMT not detected...\n") if (!$cpuht);

    # Build a 'space map' to identify which package has which ranges
    # This is overkill for something so simple but there are potential
    # use-cases for later.
    my $space = $pci_max_space/$cpusockets;
    for (my $socket=0; $socket <= $cpusockets -1; $socket++) {
        my $maxval = ($socket +1) * $space -1;
        push @space_map, $maxval;
    }

    # Print info out...
    my $cpumap = $cpu_map{'packages'};

    my $socket = 0;
    foreach (sort keys %$cpumap) {
        my $pkg = $cpu_map{'packages'}{$_};
        $cpu_map{'sockets'}{$socket} = $pkg;
        $socket++;
    }

    my $socket_map = $cpu_map{'sockets'};
    foreach (sort {$a<=>$b} keys %{$socket_map}) {
        my (@cores, @usable, @banned);
        my $scknum = $_;
        my $sck = $cpu_map{'sockets'}{$scknum};
        foreach(sort {$a<=>$b} keys %$sck) {
            # This needs to be refactored to count for smt on ppc
            push @cores, $_;
            my $sibs = $cpu_map{'sockets'}{$scknum}{$_};
            my @core_sibs = split (",", $sibs);
            $cpu_map{'sockets'}{$scknum}{'usable'}{$core_sibs[0]} = 1;
            $cpu_map{'sockets'}{$scknum}{'banned'}{$core_sibs[1]} = 1 if ($cpuht);
        }
        my $cpulist = join(",", @cores);
        my $usablecores = $cpu_map{'sockets'}{$scknum}{'usable'};
        my $bannedcores = $cpu_map{'sockets'}{$scknum}{'banned'} if ($cpuht);
        foreach(sort {$a<=>$b} keys %{$usablecores}) {
            push @usable, $_;
        }
        if ($cpuht) {
            foreach(sort {$a<=>$b} keys %$bannedcores) {
                push @banned, $_;
            }
        }
        my $set = Set::IntSpan::Fast->new(join ",", @usable);
        my $usabletotal = $set->as_string;
        $set = Set::IntSpan::Fast->new(join ",", @banned);
        my $bannedtotal = $set->as_string;
        $set = Set::IntSpan::Fast->new(join ",", @cores);
        my $corestotal = $set->as_string;
        &Output("        Processor [$scknum] has CPUs [$corestotal]\n");
        &Output("            Unique physical core CPUs: [$usabletotal]\n");
        &Output("            Logical sibling numbers:      [$bannedtotal]\n") if ($cpuht);
    }
    # Done!
}

sub GetDevInfo {
    # - Account for both msi_irqs and just irq
    # - Check for net and interface name
    # - 
    #
    my $intr_mode;
    my @devid = split(':', $_[0]);
    my @irqlist;
    my $fulldevid = $_[0];
    my $id = hex($devid[0]);
    my ($driver, $driver_ver, $fh, $irqs, $processor);
    my $driverpath = "/sys/bus/pci/devices/0000\:$fulldevid/driver/module";
    my $msi_irqpath = "/sys/bus/pci/devices/0000\:$fulldevid/msi_irqs";
    my $irqpath = "/sys/bus/pci/devices/0000\:$fulldevid/irq";
    if (-d $msi_irqpath) {
        $intr_mode = "MSI-X";
        opendir(my $irqdir, $msi_irqpath);
        while (my $direntry = readdir $irqdir) {
            next if $direntry eq '.' or $direntry eq '..';
            push @irqlist, $direntry;
            $irqs = @irqlist;
        }
    } elsif (-e $irqpath) {
        $intr_mode = "IO-APIC";
        open (my $irqfile, '<:encoding(UTF-8)', "$irqpath");
        chomp(my $entry = <$irqfile>);
        push @irqlist, $entry;
        $irqs = @irqlist;
    }

    if (-d $driverpath) {
        chomp ($driver = (split(/\//,readlink("$driverpath")))[-1]);
        open($fh, '<:encoding(UTF-8)', "$driverpath/version");
        chomp($driver_ver = <$fh>) if (-f "$driverpath/version");
        close $fh;
    }

    return if (!$irqs && $reportonlyadjustable);
    #return if (!$driver) && ($reportonlyadjustable);

    chomp(my $devname = qx#lspci -s $_[0]#);

    if (!$devname) {
        print "$_[0] not found...\n";
        return;
    }

    my $count = 0;
    foreach(@space_map) {
        if($id > $_) {
            $count++;
            next;
        } else {
            $processor = $count;
            last;
        }
    }

    if ($irqs) {
        my $fh;
        my (@finalcores, @coresinuse);
        foreach(@irqlist) {
            if (-d "/proc/irq/$_") {
                # Track in irqmap to identify devices sharing IRQ handlers
                push @{$irqmap{$_}{'devices'}}, $devname;
                $dev_map{$fulldevid}{'usableirqs'}{$_}{'valid'} = 1;
                if (!$checkprocintr && open $fh, '<:encoding(UTF-8)', "/proc/irq/$_/smp_affinity_list") {
                    chomp(my $usedcores = <$fh>);
                    push @coresinuse, $usedcores;
                    close $fh;
                } else {
                    # Failed to open smp_affinity_list
                    $checkprocintr = 1; # Set this to display notice to user
                    chomp(my $intr_map = qx#awk -F':' '/$_:/ {print}' /proc/interrupts | column -t#);
                    my @temp = split /\s+/, $intr_map;
                    for(my $core=0; $core <= $cpucores -1; $core++) {
                        push @coresinuse, $core if ($temp[$core+1] > 0);
                    }
                }
            }
        }
        @finalcores = DeDupeArray(@coresinuse);
        my $set = Set::IntSpan::Fast->new(join",", @finalcores);
        my $printcoreval = $set->as_string;
        $dev_map{$fulldevid}{'curaffinity'} = join ",", @finalcores;
    }
    # Build up map
    $dev_map{$fulldevid}{'devname'} = $devname;
    $dev_map{$fulldevid}{'processor'} = $processor;
    $dev_map{$fulldevid}{'driver'} = $driver;
    $dev_map{$fulldevid}{'driver_version'} = $driver_ver if ($driver_ver);
    $dev_map{$fulldevid}{'irqcount'} = $irqs;
    $dev_map{$fulldevid}{'irqlist'} = join(",", @irqlist);
    $dev_map{$fulldevid}{'intrmode'} = $intr_mode;
}

sub DeDupeArray {
    # Quick function to remove dupes in an array
    my %seen;
    grep !$seen{$_}++, @_;
}

sub Output {
    if (@_) { print "@_" if ($verbose) };
}

&Main();


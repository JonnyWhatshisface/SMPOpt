# smpopt

A Perl based script that helps with smp optimization decisions.

smpopt maps out the cpu architecture and the PCI devices in the system,
giving a quick and clear overview of device locaity, cpu's handling 
interrupt requests and devices sharing IRQ's. 

It is also capable of setting the SMP affinity with a simple pragmatic configuration parameter to handle the set of all devices to the desired affinity with one command.              

Please note that smpopt does have a few dependencies that must be installed to function correctly. On RHEL and YUM based systems, you should run:

```
# dnf install -y pciutils cpan util-linux
# cpan install Test experimental Data::Types Set::IntSpan::Fast
```

For Debian and APT based systems, you should use:

```
# apt-get install pciutils cpan util-linux
# cpan install Test experimental Data::types Set::IntSpan::Fast
```

Please verify package names for your distribution. The main dependencies aside from the CPAN modules is that the *lscpu* and *lspci* commands are available on your system. 

## Using smpopt

To get started quickly and get an overview of configuration as well as an initial starting suggestion, you can use the following command-line:

```
# ./smpopt.pl --scan --adjustableonly --showsharedirqs --suggest

Gather CPU info...
    System has [2] processors @ [1] cores per processor...
    Total seen CPU's including logicals: [2]
    SMT not detected...
        Processor [0] has CPUs [0]
            Unique physical core CPUs: [0]
        Processor [1] has CPUs [1]
            Unique physical core CPUs: [1]

PCI Devices Scanned: 

    00:00.0 Host bridge: Intel Corporation 440BX/ZX/DX - 82443BX/ZX/DX Host bridge (rev 01)
        Device is on Processor [0]
        Device uses [IO-APIC] for [1] IRQ handler(s): [0]
        Device has no interrupt handlers...

    00:01.0 PCI bridge: Intel Corporation 440BX/ZX/DX - 82443BX/ZX/DX AGP bridge (rev 01)
        Device is on Processor [0]
        Device uses [IO-APIC] for [1] IRQ handler(s): [0]
        Device has no interrupt handlers...

    00:07.0 ISA bridge: Intel Corporation 82371AB/EB/MB PIIX4 ISA (rev 08)
        Device is on Processor [0]
        Device uses [IO-APIC] for [1] IRQ handler(s): [0]
        Device has no interrupt handlers...

    00:07.1 IDE interface: Intel Corporation 82371AB/EB/MB PIIX4 IDE (rev 01)
        Device is on Processor [0]
        Device uses [IO-APIC] for [1] IRQ handler(s): [0]
        Device has no interrupt handlers...
        Device uses driver [ata_piix] version [2.13]

    00:07.3 Bridge: Intel Corporation 82371AB/EB/MB PIIX4 ACPI (rev 08)
        Device is on Processor [0]
        Device uses [IO-APIC] for [1] IRQ handler(s): [9]
        Device currently using IRQ handlers: [9]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:07.7 System peripheral: VMware Virtual Machine Communication Interface (rev 10)
        Device is on Processor [0]
        Device uses [MSI-X] for [2] IRQ handler(s): [56-57]
        Device currently using IRQ handlers: [56-57]
        Device uses cores [0] for interrupts
        Device uses driver [vmw_vmci] version [1.1.6.0-k]
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:0f.0 VGA compatible controller: VMware SVGA II Adapter
        Device is on Processor [0]
        Device uses [IO-APIC] for [1] IRQ handler(s): [16]
        Device currently using IRQ handlers: [16]
        Device uses cores [1] for interrupts
            *** [NOTICE] *** Device affinity appears to be nonoptimal! *** [NOTICE] ***
        Device uses driver [vmwgfx] version [2.19.0.0]
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:10.0 SCSI storage controller: Broadcom / LSI 53c1030 PCI-X Fusion-MPT Dual Ultra320 SCSI (rev 01)
        Device is on Processor [0]
        Device uses [IO-APIC] for [1] IRQ handler(s): [17]
        Device currently using IRQ handlers: [17]
        Device uses cores [0] for interrupts
        Device uses driver [mptspi] version [3.04.20]
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:11.0 PCI bridge: VMware PCI bridge (rev 02)
        Device is on Processor [0]
        Device uses [IO-APIC] for [1] IRQ handler(s): [0]
        Device has no interrupt handlers...

    00:15.0 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [24]
        Device currently using IRQ handlers: [24]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:15.1 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [25]
        Device currently using IRQ handlers: [25]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:15.2 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [26]
        Device currently using IRQ handlers: [26]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:15.3 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [27]
        Device currently using IRQ handlers: [27]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:15.4 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [28]
        Device currently using IRQ handlers: [28]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:15.5 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [29]
        Device currently using IRQ handlers: [29]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:15.6 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [30]
        Device currently using IRQ handlers: [30]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:15.7 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [31]
        Device currently using IRQ handlers: [31]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:16.0 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [32]
        Device currently using IRQ handlers: [32]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:16.1 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [33]
        Device currently using IRQ handlers: [33]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:16.2 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [34]
        Device currently using IRQ handlers: [34]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:16.3 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [35]
        Device currently using IRQ handlers: [35]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:16.4 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [36]
        Device currently using IRQ handlers: [36]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:16.5 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [37]
        Device currently using IRQ handlers: [37]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:16.6 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [38]
        Device currently using IRQ handlers: [38]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:16.7 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [39]
        Device currently using IRQ handlers: [39]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:17.0 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [40]
        Device currently using IRQ handlers: [40]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:17.1 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [41]
       Device currently using IRQ handlers: [41]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:17.2 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [42]
        Device currently using IRQ handlers: [42]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:17.3 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [43]
        Device currently using IRQ handlers: [43]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:17.4 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [44]
        Device currently using IRQ handlers: [44]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:17.5 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [45]
        Device currently using IRQ handlers: [45]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:17.6 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [46]
        Device currently using IRQ handlers: [46]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:17.7 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [47]
        Device currently using IRQ handlers: [47]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:18.0 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [48]
        Device currently using IRQ handlers: [48]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:18.1 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [49]
        Device currently using IRQ handlers: [49]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:18.2 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [50]
        Device currently using IRQ handlers: [50]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:18.3 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [51]
        Device currently using IRQ handlers: [51]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:18.4 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [52]
        Device currently using IRQ handlers: [52]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:18.5 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [53]
        Device currently using IRQ handlers: [53]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:18.6 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [54]
        Device currently using IRQ handlers: [54]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    00:18.7 PCI bridge: VMware PCI Express Root Port (rev 01)
        Device is on Processor [0]
        Device uses [MSI-X] for [1] IRQ handler(s): [55]
        Device currently using IRQ handlers: [55]
        Device uses cores [0] for interrupts
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    02:00.0 USB controller: VMware USB1.1 UHCI Controller
        Device is on Processor [0]
        Device uses [IO-APIC] for [1] IRQ handler(s): [18]
        Device currently using IRQ handlers: [18]
        Device uses cores [0] for interrupts
        Device uses driver [uhci_hcd]
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    02:01.0 Ethernet controller: Intel Corporation 82545EM Gigabit Ethernet Controller (Copper) (rev 01)
        Device is on Processor [0]
        Device uses [IO-APIC] for [1] IRQ handler(s): [19]
        Device currently using IRQ handlers: [19]
        Device uses cores [0] for interrupts
        Device uses driver [e1000]
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    02:02.0 Multimedia audio controller: Ensoniq ES1371/ES1373 / Creative Labs CT2518 (rev 02)
        Device is on Processor [0]
        Device uses [IO-APIC] for [1] IRQ handler(s): [16]
        Device currently using IRQ handlers: [16]
        Device uses cores [1] for interrupts
            *** [NOTICE] *** Device affinity appears to be nonoptimal! *** [NOTICE] ***
        Device uses driver [snd_ens1371]
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

    02:03.0 USB controller: VMware USB2 EHCI Controller
        Device is on Processor [0]
        Device uses [IO-APIC] for [1] IRQ handler(s): [17]
        Device currently using IRQ handlers: [17]
        Device uses cores [0] for interrupts
        Device uses driver [ehci_pci]
    Suggested Affinity: [0]
 Note: This is just a rough suggestion. Further optimization may need to be done...

Devices that affinity should be looked at:
    00:0f.0 VGA compatible controller: VMware SVGA II Adapter
    02:02.0 Multimedia audio controller: Ensoniq ES1371/ES1373 / Creative Labs CT2518 (rev 02)

Checking for shared IRQ handlers...
    IRQ [0] is shared by the following devices:
        00:00.0 Host bridge: Intel Corporation 440BX/ZX/DX - 82443BX/ZX/DX Host bridge (rev 01)
        00:01.0 PCI bridge: Intel Corporation 440BX/ZX/DX - 82443BX/ZX/DX AGP bridge (rev 01)
        00:07.0 ISA bridge: Intel Corporation 82371AB/EB/MB PIIX4 ISA (rev 08)
        00:07.1 IDE interface: Intel Corporation 82371AB/EB/MB PIIX4 IDE (rev 01)
        00:11.0 PCI bridge: VMware PCI bridge (rev 02)

    IRQ [16] is shared by the following devices:
        00:0f.0 VGA compatible controller: VMware SVGA II Adapter
        02:02.0 Multimedia audio controller: Ensoniq ES1371/ES1373 / Creative Labs CT2518 (rev 02)

    IRQ [17] is shared by the following devices:
        00:10.0 SCSI storage controller: Broadcom / LSI 53c1030 PCI-X Fusion-MPT Dual Ultra320 SCSI (rev 01)
        02:03.0 USB controller: VMware USB2 EHCI Controller


Suggested -set commandline for basline performance adjustment:
   ./smpopt.pl --set --device "00:07.3@0:rr;00:07.7@0:rr;00:0f.0@0:rr;00:10.0@0:rr;00:15.0@0:rr;00:15.1@0:rr;00:15.2@0:rr;00:15.3@0:rr;00:15.4@0:rr;00:15.5@0:rr;00:15.6@0:rr;00:15.7@0:rr;00:16.0@0:rr;00:16.1@0:rr;00:16.2@0:rr;00:16.3@0:rr;00:16.4@0:rr;00:16.5@0:rr;00:16.6@0:rr;00:16.
7@0:rr;00:17.0@0:rr;00:17.1@0:rr;00:17.2@0:rr;00:17.3@0:rr;00:17.4@0:rr;00:17.5@0:rr;00:17.6@0:rr;00:17.7@0:rr;00:18.0@0:rr;00:18.1@0:rr;00:18.2@0:rr;00:18.3@0:rr;00:18.4@0:rr;00:18.5@0:rr;00:18.6@0:rr;00:18.7@0:rr;02:00.0@0:rr;02:01.0@0:rr;02:02.0@0:rr;02:03.0@0:rr" --noconfirm


```



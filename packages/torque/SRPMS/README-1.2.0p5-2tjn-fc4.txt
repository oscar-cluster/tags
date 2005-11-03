# Sat Oct 08 2005  18:33:22PM    Thomas Naughton  <naughtont@ornl.gov>

I have added this SRPM for completeness since I had to make a minor
modification to the spec file in order to build on FC4/x86.  

Note, I manually renamed the file to have the 'tjn-fc4' string so
it would not conflict with the other SRPM for torque.  The only 
difference is the torque spec file (see below).

I really should have bumped the RPM release number to 3 but b/c
of dependencies for the torque-modulefile and interdependencies among
the torque RPMS themselves I couldn't even bump the Epoch number. :(

This new file corresponds to the RPMS that were built for Fedor Core 4,
i.e., distro/fc4/ .

The changes made to the torque spec file:
 - Replace Copyright: with License:
 - Add a Changelog notice,
    * Sat Oct 08 2005  13:59:51PM    Thomas Naughton  <naughtont@ornl.gov>
    - (fc4) Replace tag Copyright w/ License for rpm 4.4 legacy syntax error
      not bumping rpm rel or epoch b/c of rigid deps across rpms and modulefile


enjoy!
--tjn


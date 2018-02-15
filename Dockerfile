FROM oraclelinux:7

#Create Endeca user & group
RUN /usr/sbin/groupadd endeca_dev 
RUN /usr/sbin/useradd -G endeca_dev endeca
RUN echo endeca:endeca | chpasswd

#create SDE folder & set ownership to Endeca user
RUN mkdir /sde
RUN chown -R endeca:endeca_dev /sde


#Install unzip
RUN yum -y install unzip

#Copy installers and config files
COPY . /sde/endeca_installers
WORKDIR /sde/endeca_installers

#Copy Copying start/stop scripts
COPY config/start-endeca.sh /sde
COPY config/shutdown-endeca.sh /sde

#Unzip installers
RUN unzip /sde/endeca_installers/01_MDEX/V78211-01.zip -d /sde/endeca_installers/01_MDEX
RUN unzip /sde/endeca_installers/02_PS/V78226-01.zip -d /sde/endeca_installers/02_PS
RUN unzip /sde/endeca_installers/03_TAF/V78208-01.zip -d /sde/endeca_installers/03_TAF
RUN unzip /sde/endeca_installers/04_CAS/V78204-01.zip -d /sde/endeca_installers/04_CAS

#Fix Executable Permissions
RUN chmod -R 755 /sde/endeca_installers/01_MDEX/OCmdex6.5.2-Linux64_962107.bin
RUN chmod -R 755 /sde/endeca_installers/02_PS/OCplatformservices11.2.0-Linux64.bin
RUN chmod -R 755 /sde/endeca_installers/03_TAF/cd
RUN chmod -R 755 /sde/endeca_installers/04_CAS/OCcas11.2.0-Linux64.bin

#Switch to Endeca user
USER endeca

#Installation
#Installing MDEX
WORKDIR /sde/endeca_installers/01_MDEX/
RUN ./OCmdex6.5.2-Linux64_962107.bin -i silent -f /sde/endeca_installers/config/mdex_response.properties
RUN source /sde/endeca/MDEX/6.5.2/mdex_setup_sh.ini

#Installing Platform-and-services
WORKDIR /sde/endeca_installers/02_PS/
RUN ./OCplatformservices11.2.0-Linux64.bin -i silent -f /sde/endeca_installers/config/ps_response.properties
COPY config/eaccmd.properties /sde/endeca/PlatformServices/workspace/conf
RUN source /sde/endeca/PlatformServices/workspace/setup/installer_sh.ini

#Installing Tools and framework
COPY config/silent_response.rsp /sde/endeca_installers/03_TAF/cd/Disk1/install
WORKDIR /sde/endeca_installers/03_TAF/cd/Disk1/install
RUN  ./silent_install.sh /sde/endeca_installers/03_TAF/cd/Disk1/install/silent_response.rsp ToolsAndFrameworks /sde/endeca/ToolsAndFrameworks
COPY config/webstudio.properties /sde/endeca/ToolsAndFrameworks/11.2.0/server/workspace/conf
RUN export ENDECA_TOOLS_ROOT=/sde/endeca/ToolsAndFrameworks/11.2.0
RUN export ENDECA_TOOLS_CONF=/sde/endeca/ToolsAndFrameworks/11.2.0/server/workspace

#CAS
WORKDIR /sde/endeca_installers/04_CAS/
RUN ./OCcas11.2.0-Linux64.bin -i silent -f /sde/endeca_installers/config/cas_response.properties
COPY config/commandline.properties /sde/endeca/CAS/workspace/conf
RUN export CAS_ROOT=/sde/endeca/CAS/11.2.0
RUN sed -i 's/^\(com.endeca.casconsole.cas.server=\).*/\1localhost/' /sde/endeca/ToolsAndFrameworks/11.2.0/server/workspace/conf/casconsole.properties

#Updating bash profile
RUN echo 'source /sde/endeca/MDEX/6.5.2/mdex_setup_sh.ini' >>~/.bash_profile
RUN echo 'source /sde/endeca/PlatformServices/workspace/setup/installer_sh.ini' >>~/.bash_profile
RUN echo 'export ENDECA_TOOLS_ROOT=/sde/endeca/ToolsAndFrameworks/11.2.0' >>~/.bash_profile
RUN echo 'export ENDECA_TOOLS_CONF=/sde/endeca/ToolsAndFrameworks/11.2.0/server/wor kspace' >>~/.bash_profile
RUN echo 'export CAS_ROOT=/sde/endeca/CAS/11.2.0' >>~/.bash_profile

#Fix permissions
USER root
RUN chmod -R 755 /sde/endeca

#Delete installers
#WORKDIR /sde
RUN rm -rf /sde/endeca_installers

#Creating volume for data persistence
VOLUME /sde

#Network config
EXPOSE 8006 8500 8506

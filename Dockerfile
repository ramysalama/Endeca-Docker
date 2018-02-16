FROM oraclelinux:7

#Create Endeca user & group
RUN /usr/sbin/groupadd endeca_dev && \
 /usr/sbin/useradd -G endeca_dev endeca && \
 echo endeca:endeca | chpasswd

#create SDE folder & set ownership to Endeca user
RUN mkdir /sde && \
 chown -R endeca:endeca_dev /sde

#Install unzip
RUN yum -y install unzip wget

#Copy installers and config files
COPY . /sde/endeca_installers
WORKDIR /sde/endeca_installers

#Download installers
RUN wget --progress=bar:force https://www.dropbox.com/s/gv428k6gcx9krhj/V78211-01.zip &&\
	wget --progress=bar:force https://www.dropbox.com/s/a5ite2xo4o6kvpe/V78226-01.zip &&\
	wget --progress=bar:force https://www.dropbox.com/s/gm0nkctzhb7yf6a/V78208-01.zip &&\
	wget --progress=bar:force https://www.dropbox.com/s/63nvng5r3x33hr9/V78204-01.zip

#Copy Copying start/stop scripts
COPY config/start-endeca.sh /sde
COPY config/shutdown-endeca.sh /sde

#Unzip installers & Fix Executable Permissions
RUN unzip /sde/endeca_installers/V78211-01.zip -d /sde/endeca_installers && \
 	unzip /sde/endeca_installers/V78226-01.zip -d /sde/endeca_installers && \
 	unzip /sde/endeca_installers/V78208-01.zip -d /sde/endeca_installers && \
 	unzip /sde/endeca_installers/V78204-01.zip -d /sde/endeca_installers && \
 	chmod -R 755 /sde/endeca_installers/OCmdex6.5.2-Linux64_962107.bin && \
 	chmod -R 755 /sde/endeca_installers/OCplatformservices11.2.0-Linux64.bin && \
 	chmod -R 755 /sde/endeca_installers/cd && \
 	chmod -R 755 /sde/endeca_installers/OCcas11.2.0-Linux64.bin

#Switch to Endeca user
USER endeca

#Installation
#Installing MDEX
WORKDIR /sde/endeca_installers/
RUN ./OCmdex6.5.2-Linux64_962107.bin -i silent -f /sde/endeca_installers/config/mdex_response.properties && \
 	source /sde/endeca/MDEX/6.5.2/mdex_setup_sh.ini

#Installing Platform-and-services
RUN ./OCplatformservices11.2.0-Linux64.bin -i silent -f /sde/endeca_installers/config/ps_response.properties && \
	source /sde/endeca/PlatformServices/workspace/setup/installer_sh.ini
COPY config/eaccmd.properties /sde/endeca/PlatformServices/workspace/conf

#Installing Tools and framework
COPY config/silent_response.rsp /sde/endeca_installers/cd/Disk1/install
WORKDIR /sde/endeca_installers/cd/Disk1/install
RUN  ./silent_install.sh /sde/endeca_installers/cd/Disk1/install/silent_response.rsp ToolsAndFrameworks /sde/endeca/ToolsAndFrameworks && \
	export ENDECA_TOOLS_ROOT=/sde/endeca/ToolsAndFrameworks/11.2.0 && \
 	export ENDECA_TOOLS_CONF=/sde/endeca/ToolsAndFrameworks/11.2.0/server/workspace
COPY config/webstudio.properties /sde/endeca/ToolsAndFrameworks/11.2.0/server/workspace/conf

#CAS
WORKDIR /sde/endeca_installers/
RUN ./OCcas11.2.0-Linux64.bin -i silent -f /sde/endeca_installers/config/cas_response.properties && \
	export CAS_ROOT=/sde/endeca/CAS/11.2.0 && \
 	sed -i 's/^\(com.endeca.casconsole.cas.server=\).*/\1localhost/' /sde/endeca/ToolsAndFrameworks/11.2.0/server/workspace/conf/casconsole.properties
COPY config/commandline.properties /sde/endeca/CAS/workspace/conf

#Updating bash profile
RUN echo 'source /sde/endeca/MDEX/6.5.2/mdex_setup_sh.ini' >>~/.bash_profile && \
 	echo 'source /sde/endeca/PlatformServices/workspace/setup/installer_sh.ini' >>~/.bash_profile && \
 	echo 'export ENDECA_TOOLS_ROOT=/sde/endeca/ToolsAndFrameworks/11.2.0' >>~/.bash_profile && \
 	echo 'export ENDECA_TOOLS_CONF=/sde/endeca/ToolsAndFrameworks/11.2.0/server/wor kspace' >>~/.bash_profile && \
 	echo 'export CAS_ROOT=/sde/endeca/CAS/11.2.0' >>~/.bash_profile

#Fix permissions & elete installers
USER root
WORKDIR /sde
RUN chmod -R 755 /sde/endeca && \
	rm -rf /sde/endeca_installers

#Creating volume for data persistence
VOLUME /sde

#Network config
EXPOSE 8006 8500 8506

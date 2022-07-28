# Kudos to DOROWU for his amazing VNC 18.04 LXDE image
# docker run -it --rm -p 6080:80 kamal/melodic-desktop:latest
ARG FROM_IMAGE=dorowu/ubuntu-desktop-lxde-vnc:bionic
FROM $FROM_IMAGE AS cache
LABEL maintainer "kamal.rkara@gmail.com"

ARG USER_ID=1000
ARG GROUP_ID=1000

# Adding keys for ROS
RUN apt-get update && \
    apt-get install -y locales curl gnupg2 lsb-release wget git sudo unzip && \
    locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && \
    export LANG=en_US.UTF-8 && \
	curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add - && \
	sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list' \
	rm -rf /var/lib/apt/lists/*

ENV LANG en_US.UTF-8
ENV ROS_DISTRO="melodic"

# Installing ROS
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata && \
    apt-get install -y \
    	ros-${ROS_DISTRO}-desktop-full && \
    rm -rf /var/lib/apt/lists/*

# Dependencies for building packages
RUN apt-get update && \
	apt-get install -y python-rosdep \
			python-rosinstall \
			python-rosinstall-generator \
			python-wstool \
			build-essential \
			python-pip \
			python-argcomplete \
			terminator && \
	rm -rf /var/lib/apt/lists/*

# TB3 deps
RUN apt-get update && \
	apt-get install -y ros-melodic-move-base \ 
			ros-melodic-map-server \
			ros-melodic-dwa-local-planner \
			ros-melodic-rosserial-python \
			ros-melodic-amcl \
			ros-melodic-hls-lfcd-lds-driver && \
	rm -rf /var/lib/apt/lists/*

# Install git
RUN apt-get update && apt-get install -y git && \
    rm -rf /var/lib/apt/lists/*


# Change the default shell to Bash
SHELL [ "/bin/bash" , "-c" ]

# Set up docker user
RUN addgroup --gid $GROUP_ID docker && \
    adduser --gecos '' --disabled-password --uid $USER_ID --gid $GROUP_ID docker && \
    adduser docker sudo && \
    echo "docker ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

WORKDIR /root


USER docker
WORKDIR /home/docker
ENV HOME=$WORKDIR


USER root

RUN ["/bin/bash","-c","echo 'export HOME=/home/docker' >> /root/.bashrc && source /root/.bashrc"]

ENV USER=docker
WORKDIR /home/docker
ENV HOME=$WORKDIR

# Initialize rosdep
RUN sudo rosdep init \
 && sudo rosdep fix-permissions \
 && sudo rosdep update

# Create a Catkin workspace and clone TurtleBot3 repos
RUN source /opt/ros/melodic/setup.bash \
	&& cd /home/docker/ && mkdir -p turtlebot3_ws/src \
	&& cd turtlebot3_ws/src \
 	&& catkin_init_workspace \
 	&& git clone -b melodic-devel https://github.com/ROBOTIS-GIT/turtlebot3.git \
 	&& git clone -b melodic-devel https://github.com/ROBOTIS-GIT/turtlebot3_msgs.git \
 	&& git clone -b melodic-devel https://github.com/ROBOTIS-GIT/turtlebot3_simulations.git

RUN cd /home/docker/ && echo "export TURTLEBOT3_MODEL=waffle_pi" >> .bashrc

# Build the Catkin workspace and ensure it's sourced
RUN source /opt/ros/melodic/setup.bash \
 && cd /home/docker/turtlebot3_ws \
 && sudo rosdep install --from-paths src --ignore-src -r -y \
 && catkin_make

RUN cd /home/docker/ && echo "source /home/docker/turtlebot3_ws/devel/setup.bash" >> .bashrc
RUN cd /home/docker/ && echo "source /opt/ros/melodic/setup.bash" >> .bashrc

RUN cd /home/docker/ && mkdir -p .ignition/fuel/ 
COPY --chown=docker:docker ./config_files/config.yaml .ignition/fuel/

# Additional deps
RUN sudo apt-get update && \
	sudo apt-get install -y ros-melodic-teb-local-planner \
			ros-melodic-ros-control \
			ros-melodic-ros-controllers \
			ros-melodic-joint-state-publisher-gui \
			ros-melodic-teleop-twist-keyboard && \
	rm -rf /var/lib/apt/lists/*

# Install ridgeback and husky sims for ROOSTER
RUN sudo apt-get update && \
	sudo apt-get install -y ros-melodic-ridgeback-simulator \
			ros-melodic-ridgeback-desktop \
			ros-melodic-ridgeback-navigation \
			ros-melodic-husky-simulator \
			ros-melodic-husky-desktop \
			ros-melodic-husky-navigation && \
	rm -rf /var/lib/apt/lists/*

# Install python module PyQt4 for rooster GUI
RUN sudo apt-get update && \
	sudo apt-get install -y python-qt4 \
			python3-vcstool && \
	rm -rf /var/lib/apt/lists/*

# Setup ROOSTER workspace
RUN source /opt/ros/melodic/setup.bash \
	&& cd /home/docker/ && mkdir -p rooster_ws/src \
	&& cd rooster_ws/ \
	&& wget https://raw.githubusercontent.com/KamalanathanN/rooster/main/rooster.repos \
	&& vcs import src < rooster.repos \
	&& rosdep install --from-paths src --ignore-src --rosdistro melodic -y \
 	&& catkin_make 

RUN cd /home/docker/ && echo "source /home/docker/rooster_ws/devel/setup.bash" >> .bashrc && echo "export QT_X11_NO_MITSHM=1" >> .bashrc

RUN sudo apt-get update && sudo apt-get upgrade -y

ENTRYPOINT ["/startup.sh"]

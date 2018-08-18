###############################################################
###############################################################
#### BUILD IMAGE
#### OpenJDK image produces weird results with JLink (400mb + sizes)
FROM alpine:3.8 AS signalbuild
ENV JAVA_HOME=/opt/jdk \
    PATH=${PATH}:/opt/jdk/bin \
    LANG=C.UTF-8

RUN set -ex && \
    apk add --no-cache bash && \
    wget https://download.java.net/java/early_access/alpine/22/binaries/openjdk-11-ea+22_linux-x64-musl_bin.tar.gz -O jdk.tar.gz && \
    mkdir -p /opt/jdk && \
    tar zxvf jdk.tar.gz -C /opt/jdk --strip-components=1 && \
    rm jdk.tar.gz && \
    rm /opt/jdk/lib/src.zip

RUN mkdir -p /usr/src/mods/jars
RUN mkdir -p /usr/src/mods/compiled

COPY . /usr/src
WORKDIR /usr/src

RUN javac -Xlint:unchecked -d /usr/src/mods/compiled --module-source-path /usr/src/src $(find src -name "*.java")
RUN jar --create --file /usr/src/mods/jars/joostvdg.demo.signal.jar --module-version 1.0  -e com.github.joostvdg.demo.signal.SignalApp\
    -C /usr/src/mods/compiled/joostvdg.demo.signal .

RUN rm -rf /usr/bin/signal-image
RUN jlink \
    --verbose \
    --compress 2 \
    --no-header-files \
    --no-man-pages \
    --strip-debug \
    --limit-modules java.base \
    --launcher signal=joostvdg.demo.signal \
    --module-path /usr/src/mods/jars/:$JAVA_HOME/jmods \
    --add-modules joostvdg.demo.signal \
     --output /usr/bin/signal-image
RUN /usr/bin/signal-image/bin/java --list-modules

###############################################################
###############################################################
##### RUNTIME IMAGE - ALPINE
FROM panga/alpine:3.8-glibc2.27
LABEL authors="Joost van der Griendt <joostvdg@gmail.com>"
LABEL version="0.1.0"
LABEL description="Docker image for playing with java applications for graceful shutdown with Docker & Kubernetes."
ENV DATE_CHANGED="20180728-2355"
ENTRYPOINT ["/usr/bin/signal/bin/signal","-XX:+UseCGroupMemoryLimitForHeap", "-XX:+UnlockExperimentalVMOptions"]
COPY --from=signalbuild /usr/bin/signal-image/ /usr/bin/signal

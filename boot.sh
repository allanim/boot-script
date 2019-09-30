#!/bin/bash

# Read configuration
THIS_DIR=$(pwd)
THIS_FILE_NAME="$THIS_DIR"/$(basename "$0")

APP_CONFIG="${THIS_FILE_NAME%.*}.conf"
test -e "$APP_CONFIG" || { echo "$APP_CONFIG not existing";
        if [ "$1" = "stop" ]; then exit 0;
        else exit 6; fi; }
test -r "$APP_CONFIG" || { echo "$APP_CONFIG not readable. Perhaps you forgot 'sudo'?";
        if [ "$1" = "stop" ]; then exit 0;
        else exit 6; fi; }
[[ -r "${APP_CONFIG}" ]] && source "${APP_CONFIG}"

if [ "x$APP_NAME" = "x" ]; then
    APP_NAME=$(basename "${APP_CONFIG%.*}")
fi
if [ "x$JARFILE" = "x" ]; then
    JARFILE=$(basename "${APP_CONFIG%.*}.jar")
fi

LIBRARY_DIR="$THIS_DIR/lib"
LIBRARY_CONFIG="$LIBRARY_DIR"/$(basename "${JARFILE%.*}.conf")

APP_SERVICE_LINK="/etc/init.d/$APP_NAME"
GIT_SOURCES_NAME="git-sources";

# ANSI Colors
echoRed() { echo $'\e[0;31m'"$1"$'\e[0m'; }
echoGreen() { echo $'\e[0;32m'"$1"$'\e[0m'; }
echoYellow() { echo $'\e[0;33m'"$1"$'\e[0m'; }

# Check installed app
isInstalled() { sudo test -r "$APP_SERVICE_LINK" || { echoRed "$APP_NAME not installed"; return 5; } }

# Git Clone
gitClone() {
    test -n "$GIT_URL" || { echoRed "You must have to set GIT_URL"; exit 0; }
    type -p git > /dev/null 2>&1 || { echoRed "You must have to install GIT"; exit 0; }

    GIT_BRANCH="master";
    if [[ ! -e "$GIT_SOURCES_NAME" ]]; then
        git clone "$GIT_URL" "$GIT_SOURCES_NAME";
        echoGreen "Clone from $GIT_URL"
    else
        cd ./"$GIT_SOURCES_NAME";
        git pull origin "$GIT_BRANCH";
        cd ..;
        echoGreen "Pull from $GIT_URL"
    fi
}

gradleBuild() {
    cd "./$GIT_SOURCES_NAME";
    chmod 755 ./gradlew;
    ./gradlew clean bootjar;
    cd ..;

    test -r "$GIT_SOURCES_NAME/build/libs/$JARFILE" || { echoRed "Failed to build '$JARFILE'"; exit 0; }
}

copyLibrary() {
    test -r "$LIBRARY_DIR" || { mkdir -p "$LIBRARY_DIR" &> /dev/null }
    sudo cp "./$GIT_SOURCES_NAME/build/libs/$JARFILE" "$LIBRARY_DIR/"
}

createService() {
    sudo ln -s "$LIBRARY_DIR/$JARFILE" "$APP_SERVICE_LINK"
    sudo ln -s "$APP_CONFIG" "$LIBRARY_CONFIG"
    sudo chown root:root "$LIBRARY_DIR/$JARFILE"
    sudo chown -h root:root "$LIBRARY_CONFIG"
    sudo chmod 500 "$LIBRARY_DIR/$JARFILE"
    sudo chmod 400 "$LIBRARY_CONFIG"
}

case "$1" in
    install)
        sudo test -r "$APP_SERVICE_LINK" && { echoGreen "Already installed '$APP_SERVICE_LINK'"; exit 0; } 
        gitClone;
        gradleBuild;
        copyLibrary;
        createService;
        echoGreen "Installed $APP_NAME"
        ;;
    uninstall)
        sudo test -r "$APP_SERVICE_LINK" || { echoYellow "$APP_NAME is not installed"; exit 0; } 
        sudo rm -rf "$APP_SERVICE_LINK";
        sudo rm -rf "./$GIT_SOURCES_NAME";
        sudo unlink "$LIBRARY_CONFIG"
        sudo rm -rf "$LIBRARY_DIR"
        echoGreen "Uninstalled $APP_NAME"
        ;;
    deploy)
        isInstalled || { exit $?; } 
        gitClone;
        gradleBuild;
        copyLibrary;
        echoGreen "Deployed $APP_NAME"
        ;;
    start)
        isInstalled || { exit $?; } 
        sudo service "$APP_NAME" start
        ;;
    stop)
        isInstalled || { exit $?; } 
        sudo service "$APP_NAME" stop
        ;;
    force-stop)
        isInstalled || { exit $?; } 
        sudo service "$APP_NAME" force-stop
        ;;
    restart)
        isInstalled || { exit $?; } 
        sudo service "$APP_NAME" restart
        ;;
    force-reload)
        isInstalled || { exit $?; } 
        sudo service "$APP_NAME" force-reload
        ;;
    status)
        isInstalled || { exit $?; } 
        sudo service "$APP_NAME" status
        ;;
    run)
        isInstalled || { exit $?; } 
        sudo service "$APP_NAME" run
        ;;
    *)
    echo $"Usage: $0 {deploy|start|stop|force-stop|restart|force-reload|status|run}"
    exit 1
esac

exit 0

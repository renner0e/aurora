/*
 *  SPDX-FileCopyrightText: 2025 renner <renner0@posteo.de>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Qt5Compat.GraphicalEffects

import org.kde.plasma.welcome

Page {
    heading: i18ndc("plasma-welcome-aurora", "@info:window", "glorified ujust gui IDK man")
    description: xi18ndc("plasma-welcome-aurora", "@info:usagetip", "Make a super long text why DX is super cool lorem ipsum. Cool brew stuff idk.")
    id: root
    topContent: [
        Kirigami.UrlButton {
            id: infoLinkDX
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: i18ndc("plasma-welcome-aurora", "@action:button", "What is Aurora-DX?")
            url: "https://docs.getaurora.dev/dx/aurora-dx-intro"
        },
        QQC2.Button {
            id: enableDX
            text: i18nd("plasma-welcome-aurora", "Enable Developer Mode")
            onClicked: {
                Utils.runCommand("pkexec fedora-third-party enable");
                showPassiveNotification(i18nd("plasma-welcome-aurora", "Rebasing to DX in the background"));
                disableDX.visible = true;
                enableDX.visible = false;
            }
            Layout.topMargin: Kirigami.Units.largeSpacing
        },
        QQC2.Button {
            id: wallpaperDownload
            text: i18nd("plasma-welcome-aurora", "Install all the cool wallpapers from the homebrew tap")
            onClicked: {
                Utils.runCommand("");
                showPassiveNotification(i18nd("plasma-welcome-aurora", "Rebasing to DX in the background"));
                disableDX.visible = true;
                enableDX.visible = false;
            }
            Layout.topMargin: Kirigami.Units.largeSpacing
        },
        QQC2.Button {
            id: installBrewGoodies
            text: i18nd("plasma-welcome-aurora", "Install Fonts")
            onClicked: {
                Utils.runCommand("ujust install-fonts");
                showPassiveNotification(i18nd("plasma-welcome-aurora", "Installing "));
                disableThirdParty.visible = false;
                enableThirdParty.visible = true;
            }
            Layout.topMargin: Kirigami.Units.largeSpacing
        },
        QQC2.Button {
            id: installAiGoodies
            text: i18nd("plasma-welcome-aurora", "Install AI Tools")
            onClicked: {
                Utils.runCommand("ujust install-ai-tools");
                showPassiveNotification(i18nd("plasma-welcome-aurora", "Installing AI Tools"));
                disableThirdParty.visible = false;
                enableThirdParty.visible = true;
            }
            Layout.topMargin: Kirigami.Units.largeSpacing
        }
    ]
    ColumnLayout {
        anchors.fill: parent
        spacing: root.padding
        id: pandaImage
        Image {
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 50

            fillMode: Image.PreserveAspectFit
            mipmap: true
            source: "/usr/share/backgrounds/aurora/aurora-wallpaper-4/contents/images/3840x2160.png"
        }
    }
    Component.onCompleted: {
        Utils.runCommand("fedora-third-party query --quiet", callback);
    }
    property var callback: (returnStatus, outputText) => {
        if (returnStatus == 0) {
            enableThirdParty.visible = false;
            disableThirdParty.visible = true;
            console.log('Third Party Repositories are enabled');
        } else {
            enableThirdParty.visible = true;
            disableThirdParty.visible = false;
            console.log('Third Party Repositories are not enabled');
        }
    }
}


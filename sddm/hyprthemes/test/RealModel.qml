// What SDDM's own SessionModel answers, for checking the role numbers the wrapper relies on.
import QtQuick

Item {
    Component.onCompleted: {
        for (let i = 0; i < sessionModel.count; ++i) {
            const m = sessionModel.index(i, 0);
            console.warn("TEST SESSION " + i + " file=" + sessionModel.data(m, 258) + " name=" + sessionModel.data(m, 260));
        }
        console.warn("TEST LASTINDEX " + sessionModel.lastIndex);
        console.warn("TEST DONE");
    }
}

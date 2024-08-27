import fs from './filesystem.js';
import glob from 'glob';
import symfony from './symfony.js';
import utils from './utils.js';

function transpile(global, callback = null) {
    if (!global.options.enableTranslations) {
        if (typeof callback === 'function') {
            callback();
        }

        return;
    }

    symfony.dumpTranslations(global.options);

    const files = glob.sync(global.options.outputFolder + '/translations/*/' + global.options.lang + '.json');
    let remainingTranslations = files.length;

    const elmSubscription = data => {
        if (data.type !== 'translation') {
            return;
        }

        if (data.succeeded) {
            fs.writeIfChanged(global.options.elmRoot + '/' + data.file.name, data.file.content);
        } else {
            utils.error(data.error)
        }

        remainingTranslations--;
        if (remainingTranslations === 0) {
            global.transpiler.ports.sendToJs.unsubscribe(elmSubscription);

            if (typeof callback === 'function') {
                callback();
            }
        }
    };

    global.transpiler.ports.sendToJs.subscribe(elmSubscription);
    files.map(file => {
        const content = fs.readFile(file);
        global.transpiler.ports.sendToElm.send({
            translation: {
                name: file,
                content: content,
                version: global.options.elmVersion,
                envVariables: global.options.envVariables,
            }
        });
    });
}

module.exports = {
    transpile,
};

import fs from './filesystem.js';
import glob from 'glob';
import symfony from './symfony.js';
import utils from './utils.js';

function transpile(global) {
    if (!global.options.enableTranslations) {
        return;
    }

    symfony.dumpTranslations(global.options.tmpFolder, global.options.dev);

    const files = glob.sync('./' + global.options.tmpFolder + '/translations/*/' + global.options.lang + '.json');
    let remainingTranslations = files.length;

    const elmSubscription = function (data) {
        utils.onSuccess('translation', data, function() {
            fs.writeIfChanged(global.options.generatedCodeFolder + '/' + data.file.name, data.file.content);
        });

        remainingTranslations--;
        if (remainingTranslations === 0) {
            global.transpiler.ports.sendToJs.unsubscribe(elmSubscription);
            callback();
        }
    };

    global.transpiler.ports.sendToJs.subscribe(elmSubscription);
    files.map(file => {
        const content = fs.readFile(file);
        global.transpiler.ports.sendToElm.send({
            translation: {
                name: file,
                content: content,
                version: global.options.elmVersion
            }
        });
    });
}

module.exports = {
    transpile,
};

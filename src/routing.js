import fs from './filesystem.js';
import symfony from './symfony.js';
import utils from './utils.js';

function transpile(global) {
    if (!global.options.enableRouting) {
        return;
    }

    let content = symfony.queryRouting('debug:router --format=json', global.options);

    const elmSubscription = function (data) {
        utils.onSuccess('routing', data, function() {
            fs.writeIfChanged(global.options.generatedCodeFolder + '/Routing.elm', data.content);
        });

        global.transpiler.ports.sendToJs.unsubscribe(elmSubscription);
    };

    global.transpiler.ports.sendToJs.subscribe(elmSubscription);
    global.transpiler.ports.sendToElm.send({
        routing: {
            urlPrefix: global.options.dev ? global.options.urlPrefix : '',
            content: content,
            version: global.options.elmVersion
        }
    });
}

module.exports = {
    transpile,
};

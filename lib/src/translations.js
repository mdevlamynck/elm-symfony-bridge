import fs from './filesystem.js';
import { glob } from 'glob';
import symfony from './symfony.js';
import utils from './utils.js';

async function transpile(global) {
    if (!global.options.enableTranslations) {
        return;
    }

    const id = Math.floor(Math.random() * (1000));

    console.time(`[PERF] ${id} translations cmd`);
    await symfony.dumpTranslations(global.options);
    console.timeEnd(`[PERF] ${id} translations cmd`);

    const files = await glob(global.options.outputFolder + '/translations/*/' + global.options.lang + '.json');

    console.time(`[PERF] ${id} translations elm`);
    await Promise.all(files.map(async file => {
        console.time(`[PERF] ${id} translations elm ${file}`);
        const content = await fs.readFile(file);

        const data = await utils.callElm(global.transpiler, {
            translation: {
                name: file,
                content: content,
                version: global.options.elmVersion,
                envVariables: global.options.envVariables,
            }
        });

        if (data.succeeded) {
            await fs.writeFile(global.options.elmRoot + '/' + data.file.name, data.file.content);
        } else {
            utils.error(data.error)
        }
        console.timeEnd(`[PERF] ${id} translations elm ${file}`);
    }));
    console.timeEnd(`[PERF] ${id} translations elm`);
}

module.exports = {
    transpile,
};

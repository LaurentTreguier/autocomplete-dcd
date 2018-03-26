const provider = require('./dcd-provider');

module.exports = {
  config: require('./config'),
  activate: () => {
    goodAndBadNews();
    return provider.installDcd();
  },
  deactivate: () => provider.stopServer(),
  provide: () => provider
};

function goodAndBadNews() {
  atom.notifications.addInfo('You have autocomplete-dcd installed. I have good news and bad news.', {
    buttons: [{ text: 'Ok, tell me the bad news first', onDidClick: badNews }]
  });
}

function badNews() {
  atom.notifications.addWarning('The autocomplete-dcd package is now unmaintained.', {
    buttons: [{ text: 'And the good news ?', onDidClick: goodNews }]
  });
}

function goodNews() {
  atom.notifications.addSuccess('It is superseded by another package : ide-dlang', {
    buttons: [{ text: 'Why though ?', onDidClick: whyThough }]
  });
}

function whyThough() {
  atom.notifications.addInfo('ide-dlang provides basic autocompletion, formats code, and more should be coming ! See https://github.com/LaurentTreguier/ide-dlang and https://github.com/LaurentTreguier/dls for more details');
}

// Équivalents de secours pour les vieux WebView Android (Chrome < 97).
// Ces fonctions récentes ne peuvent pas être converties au build : on les ajoute si absentes.
if (!Array.prototype.at) {
  Array.prototype.at = function at(i) { return this[i < 0 ? this.length + i : i] }
}
if (!Array.prototype.findLastIndex) {
  Array.prototype.findLastIndex = function findLastIndex(test) {
    for (let i = this.length - 1; i >= 0; i--) if (test(this[i], i, this)) return i
    return -1
  }
}
if (!Object.hasOwn) {
  Object.hasOwn = (object, key) => Object.prototype.hasOwnProperty.call(object, key)
}

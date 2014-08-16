var Set = function() {};
Set.prototype.add = function(bla) {
  if (typeof bla != "undefined") {
    this[bla] = true;
    return true;
  }
  return false;
}
Set.prototype.remove = function(bla) {delete this[bla];}

module.exports = Set;
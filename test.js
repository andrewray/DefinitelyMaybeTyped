/// <reference path="../../DefinitelyTyped/jquery/jquery.d.ts"/>

// 1st pass, merge interfaces - even though z is declared later, it
// is needed here.
var myvec_1 = { x: 2, y: 3, z: 0 };

var vec = (function () {
    // public parameters create public properties
    function vec(x, y) {
        this.x = x;
        this.y = y;
    }
    vec.prototype.add = function (z) {
        this.x = this.x + z;
        this.y = this.y + z;
    };
    vec.prototype.add2 = function (v) {
        this.x = this.x + v.x;
        this.y = this.y + v.y;
    };
    return vec;
})();

var myvec_i = { x: 2, y: 3, z: 4 };
var myvec = new vec(0, 1);
myvec.add2(myvec_i);

function prepareList() {
    $('#expList').find('li:has(ul)').click(function (event) {
        if (this == event.target) {
            $(this).toggleClass('expanded');
            $(this).children('ul').toggle('medium');
        }
        return false;
    }).addClass('collapsed').children('ul').hide();
}

(function() {
  var Editor;
  Editor = Function.inherit(function(area) {
    if (!area) {
      throw new Error('Missing area element');
    }
    this.area = area;
    this.types = {
      paragraph: {
        tag: 'p'
      },
      h1: {
        tag: 'h1',
        NEXT: 'paragraph'
      },
      h2: {
        tag: 'h2',
        NEXT: 'paragraph'
      }
    };
    this.DEFAULT_TYPE = 'h1';
    this.ACTIVE_TYPE = this.DEFAULT_TYPE;
  }, {
    activate: function() {
      this.active = true;
      this.area.attr('contenteditable', true);
      this._addListeners();
      if (!this.area.html()) {
        this.erase();
      }
      return this;
    },
    deactivate: function() {
      this.active = false;
      this.area.attr('contenteditable', false);
      return this;
    },
    erase: function() {
      this.area.html('');
      this._addBlock(this.DEFAULT_TYPE);
      return this;
    },
    setBlockType: function(type) {
      var cnts, node, old;
      if (!this.active) {
        return false;
      }
      type = this.types[type];
      old = this._getCaretBlock().firstChild;
      node = new Element(type.tag, type.attrs);
      cnts = Array.prototype.slice.call(old.childNodes);
      cnts.forEach(function(cnt) {
        return node.appendChild(cnt);
      });
      old.insert({
        after: node
      });
      old.remove();
      return this;
    },
    indent: function() {
      var block, caret, prev, sub;
      block = this._getCaretBlock();
      if (block !== null) {
        prev = block.previousSibling;
      }
      if (!prev) {
        return false;
      }
      caret = this._getCaret();
      sub = prev.lastChild;
      if (sub.tagName !== 'UL') {
        sub = this._createSub(prev);
      }
      sub.appendChild(block);
      this._setCaret(caret);
      return this;
    },
    outdent: function() {
      var block, caret, parent_sub, sub;
      block = this._getCaretBlock();
      if (block.parentNode === this.area) {
        return false;
      }
      caret = this._getCaret();
      if (block.nextSibling !== null) {
        sub = block.lastChild;
        if (sub.tagName !== 'UL') {
          sub = this._createSub(block);
        }
        while (block.nextSibling !== null) {
          sub.appendChild(block.nextSibling);
        }
      }
      parent_sub = block.parentNode;
      parent_sub.parentNode.insert({
        after: block
      });
      if (parent_sub.childNodes.length === 0) {
        parent_sub.remove();
      }
      this._setCaret(caret);
      return this;
    },
    _createSub: function(node) {
      var sub;
      sub = new Element('ul');
      node.appendChild(sub);
      return sub;
    },
    _getCaretNode: function() {
      return window.getSelection().focusNode;
    },
    _getCaretBlock: function(old) {
      var area;
      area = this.area;
      if (old === void 0) {
        old = this._getCaretNode();
      }
      if (old !== null && old !== document.body) {
        while (old.tagName !== 'LI') {
          old = old.parentNode;
        }
      }
      if (old !== document.body) {
        return old;
      } else {
        return null;
      }
    },
    _getCaret: function() {
      var sel;
      sel = window.getSelection();
      if (sel.focusNode) {
        return [sel.focusNode, sel.focusOffset, sel.anchorNode, sel.anchorOffset];
      } else {
        return null;
      }
    },
    _setCaret: function(caret) {
      var range, sel;
      sel = window.getSelection();
      range = document.createRange();
      range.setStart(caret[2], caret[3]);
      range.setEnd(caret[0], caret[1]);
      sel.removeAllRanges();
      return sel.addRange(range);
    },
    _setCaretAt: function(node) {
      var range, sel;
      node = node.firstChild;
      sel = window.getSelection();
      range = document.createRange();
      range.setStart(node, 0);
      range.setEnd(node, 0);
      sel.removeAllRanges();
      return sel.addRange(range);
    },
    _getNextTypeKey: function() {
      var active_type;
      active_type = this.types[this.ACTIVE_TYPE];
      if (active_type.NEXT !== void 0) {
        return active_type.NEXT;
      } else {
        return this.ACTIVE_TYPE;
      }
    },
    _addBlock: function(type_key) {
      var block, cnt, frag, node, type;
      frag = this._getRightFragment();
      if (type_key === void 0 && frag !== null && frag.childNodes.length !== 0) {
        type_key = this.ACTIVE_TYPE;
      }
      if (type_key === void 0) {
        type_key = this._getNextTypeKey();
      }
      type = this.types[type_key];
      node = new Element('li');
      node.data('type', type_key);
      block = this._getCaretBlock();
      if (block) {
        block.insert({
          after: node
        });
      } else {
        this.area.appendChild(node);
      }
      cnt = new Element(type.tag, type.attrs);
      node.appendChild(cnt);
      cnt.appendChild(frag);
      return node;
    },
    _getRightFragment: function() {
      var block, cnt, range, sel;
      sel = window.getSelection();
      if (sel.focusNode === null) {
        return null;
      }
      range = sel.getRangeAt(0);
      block = this._getCaretBlock(sel.focusNode);
      if (!block) {
        return document.createDocumentFragment();
      }
      cnt = block.firstChild.lastChild || block.firstChild || block;
      range.setEnd(cnt, cnt.length);
      return range.extractContents();
    },
    _addListeners: function() {
      var that;
      that = this;
      this.area.addEventListener('keydown', (function(e) {
        switch (e.keyCode) {
          case 13:
            e.preventDefault();
            return that._setCaretAt(that._addBlock());
          case 9:
            e.preventDefault();
            if (!e.shiftKey) {
              return that.indent();
            } else {
              return that.outdent();
            }
        }
      }), false);
      this.area.addEventListener('keyup', (function(e) {
        var apples, node, range, sel;
        switch (e.keyCode) {
          case 8:
          case 46:
            sel = window.getSelection();
            apples = sel.focusNode.parentNode.find('span.Apple-style-span');
            range = sel.getRangeAt(0);
            apples.forEach(function(apple) {
              var cnts;
              cnts = Array.prototype.slice.call(apple.childNodes);
              cnts.forEach(function(cnt) {
                return apple.insert({
                  before: cnt
                });
              });
              return apple.remove();
            });
            range.reapply();
        }
        node = that._getCaretNode();
        while (node.tagName !== 'LI') {
          node = node.parentNode;
        }
        return that.ACTIVE_TYPE = node.data('type') || that.DEFAULT_TYPE;
      }), false);
      return this;
    }
  });
  window.TakeNote = Editor;
  return;
}).call(this);

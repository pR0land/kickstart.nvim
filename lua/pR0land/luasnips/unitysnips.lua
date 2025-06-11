local ls = require 'luasnip'
-- snips for unity taken from: https://github.com/apyra/nvim-unity/tree/master?tab=readme-ov-file

local s, t, i = ls.snippet, ls.text_node, ls.insert_node

return {
  s('start', { t 'void Start() {', t { '', '    ' }, i(1), t { '', '}' } }),
  s('update', { t 'void Update() {', t { '', '    ' }, i(1), t { '', '}' } }),
  s('awake', { t 'void Awake() {', t { '', '    ' }, i(1), t { '', '}' } }),
  s('fixedupdate', { t 'void FixedUpdate() {', t { '', '    ' }, i(1), t { '', '}' } }),
  s('onenable', { t 'void OnEnable() {', t { '', '    ' }, i(1), t { '', '}' } }),
  s('ondisable', { t 'void OnDisable() {', t { '', '    ' }, i(1), t { '', '}' } }),
  s('ontriggerenter', { t 'void OnTriggerEnter(Collider other) {', t { '', '    ' }, i(1), t { '', '}' } }),
  s('oncollisionenter', { t 'void OnCollisionEnter(Collision collision) {', t { '', '    ' }, i(1), t { '', '}' } }),
  s('serializefield', { t '[SerializeField] private ', i(1, 'Type'), t ' ', i(2, 'variableName'), t ';' }),
  s('publicfield', { t 'public ', i(1, 'Type'), t ' ', i(2, 'variableName'), t ';' }),
  s('log', { t 'Debug.Log("', i(1, 'message'), t '");' }),
  s('class', {
    t 'using UnityEngine;',
    t { '', '' },
    t 'public class ',
    i(1, 'ClassName'),
    t ' : MonoBehaviour',
    t { '', '{' },
    t { '', '    ' },
    i(2, '// Your code here'),
    t { '', '}' },
  }),
}

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
const source = (await readFile(new URL('../../app/javascript/controllers/clipboard_controller.js', import.meta.url), 'utf8')).replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
const { default: Clipboard } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)

test('copy reports success only after clipboard resolves and failure honestly', async () => {
  const controller = new Clipboard()
  controller.hasTextValue = true
  controller.textValue = 'nonsecret-example'
  controller.hasStatusTarget = true
  controller.statusTarget = { textContent: '' }
  controller.hasIconTarget = false
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { clipboard: { writeText: async text => assert.equal(text, 'nonsecret-example') } } })
  const event = { preventDefault() {}, stopPropagation() {} }
  await controller.copy(event)
  assert.equal(controller.statusTarget.textContent, 'Value copied.')
  navigator.clipboard.writeText = async () => { throw new Error('denied') }
  await controller.copy(event)
  assert.equal(controller.statusTarget.textContent, 'Copy failed. Try again or copy the revealed value.')
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: {} })
  await controller.copy(event)
  assert.equal(controller.statusTarget.textContent, 'Copy failed. Try again or copy the revealed value.')
})

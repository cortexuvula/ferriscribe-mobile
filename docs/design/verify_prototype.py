"""Verify the standalone design prototype, not the Flutter application."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

BASE = Path(__file__).resolve().parent
URL = (BASE / 'prototype.html').as_uri()
report = {'artifact': 'design simulation only', 'flows': {}, 'layout': [], 'page_errors': [], 'external_requests': []}

with sync_playwright() as p:
    browser = p.chromium.launch(executable_path='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless=True)
    page = browser.new_page(viewport={'width': 1320, 'height': 1110}, device_scale_factor=1)
    page.on('pageerror', lambda e: report['page_errors'].append(str(e)))
    page.on('request', lambda req: report['external_requests'].append(req.url) if not req.url.startswith('file:') else None)
    page.goto(URL + '?theme=light')
    page.get_by_role('button', name='New consultation', exact=True).click()
    page.get_by_role('button', name='Start recording', exact=True).click()
    page.get_by_role('button', name='Discard recording', exact=True).click()
    assert page.get_by_role('dialog').is_visible()
    page.get_by_role('button', name='Keep recording', exact=True).click()
    page.get_by_role('button', name='Stop & generate SOAP', exact=True).click()
    page.get_by_role('button', name='Simulate SOAP ready', exact=True).click()
    page.get_by_role('button', name='Open SOAP note', exact=True).click()
    report['flows']['record_to_document'] = 'pass (simulated)'
    page.get_by_role('button', name='Edit', exact=True).click()
    modified = 'SYNTHETIC MODIFIED TEXT — retained on failed save'
    page.locator('#doc-edit').fill(modified)
    page.locator('#state-picker').select_option('saveerror')
    page.get_by_role('button', name='Retry save', exact=True).click()
    assert page.locator('#doc-edit').input_value() == modified
    page.get_by_role('button', name='Keep reading', exact=True).click()
    assert page.get_by_role('dialog').is_visible()
    page.get_by_role('button', name='Keep editing', exact=True).click()
    page.locator('#state-picker').select_option('normal')
    page.get_by_role('button', name='Save changes', exact=True).click()
    assert modified in page.locator('.document').inner_text()
    report['flows']['failed_save_buffer_and_exit_guard'] = 'pass (simulated)'
    page.get_by_role('button', name='Export & share', exact=True).click()
    page.get_by_role('radio', name='Word (.docx) Editable document').click()
    assert page.get_by_role('radio', name='Word (.docx) Editable document').get_attribute('aria-checked') == 'true'
    page.get_by_role('button', name='Continue to share', exact=True).click()
    assert page.get_by_role('heading', name='System sharing').is_visible()
    page.get_by_role('button', name='Return to document', exact=True).click()
    report['flows']['format_and_share'] = 'pass (simulation; no exported file)'
    page.locator('#screen-picker').select_option('peer')
    page.get_by_role('button', name='Generate discussion', exact=True).click()
    assert page.locator('.field-error').all_text_contents() == ['This field is required.'] * 3
    report['flows']['peer_required_fields'] = 'pass'
    page.locator('#screen-picker').select_option('settings')
    page.get_by_role('radio', name='Dark', exact=True).click()
    page.goto(URL)
    assert 'dark' in (page.locator('.phone').get_attribute('class') or '')
    page.locator('#theme-picker').select_option('system')
    for mode in ('light', 'dark', 'light'):
        page.emulate_media(color_scheme=mode)
        page.wait_for_function("document.querySelector('.phone').classList.contains('dark') === matchMedia('(prefers-color-scheme: dark)').matches")
    report['flows']['theme_restore_and_system_changes'] = 'pass'
    page.locator('#screen-picker').select_option('home')
    page.locator('[data-input="search"]').fill('NO SUCH SYNTHETIC PATIENT')
    assert page.get_by_role('heading', name='No matches').is_visible()
    page.get_by_role('button', name='Clear search', exact=True).click()
    assert page.locator('.consult-row').count() == 3
    report['flows']['local_search'] = 'pass'
    page.locator('#state-picker').select_option('offline')
    page.locator('#screen-picker').select_option('prepare')
    assert page.get_by_role('button', name='Start recording', exact=True).is_disabled()
    page.locator('#screen-picker').select_option('reader')
    assert page.get_by_role('button', name='Edit', exact=True).count() == 0
    assert page.get_by_role('button', name='Copy text', exact=True).count() == 1
    report['flows']['offline_readonly'] = 'pass'
    # Every screen in both modes at three widths, including large-text review mode.
    screens = page.locator('#screen-picker option').evaluate_all('(els)=>els.map(e=>e.value)')
    for width in (320, 390, 1320):
        page.set_viewport_size({'width': width, 'height': 1000})
        for theme in ('light', 'dark'):
            page.goto(URL + '?theme=' + theme)
            for screen in screens:
                page.locator('#screen-picker').select_option(screen)
                check = page.locator('.phone').evaluate('''el => ({
                    outerOverflow: document.documentElement.scrollWidth > window.innerWidth + 1,
                    contentOverflow: el.querySelector('.scroll').scrollWidth > el.querySelector('.scroll').clientWidth + 1,
                    shortButtons: [...el.querySelectorAll('button')].filter(b => b.getBoundingClientRect().height < 47.5).map(b=>b.textContent.trim()),
                    footerOverlap: !!el.querySelector('.footer') && el.querySelector('.scroll').getBoundingClientRect().bottom > el.querySelector('.footer').getBoundingClientRect().top + 1
                })''')
                report['layout'].append({'width': width, 'theme': theme, 'screen': screen, **check})
    page.set_viewport_size({'width': 390, 'height': 1000})
    page.goto(URL + '?screen=reader&theme=dark')
    page.get_by_role('button', name='Larger text', exact=True).click()
    page.screenshot(path=str(BASE / 'reader-large-dark.png'), full_page=True)
    scroll = page.locator('.phone .scroll')
    scroll.evaluate('(el)=>el.scrollTop=el.scrollHeight')
    assert 'line breaks and edit controls.' in page.locator('.document').inner_text()
    report['flows']['document_scroll'] = 'pass; footer is outside scroll area, not overlaid'
    page.set_viewport_size({'width': 1320, 'height': 1110})
    for theme in ('light', 'dark'):
        page.goto(URL + '?board=1&theme=' + theme)
        page.screenshot(path=str(BASE / f'overview-{theme}.png'), full_page=True)
    browser.close()

failures = [x for x in report['layout'] if x['outerOverflow'] or x['contentOverflow'] or x['shortButtons'] or x['footerOverlap']]
report['layout_failures'] = failures
report['screen_count'] = len(screens)
report['layout_case_count'] = len(report['layout'])
(BASE / 'prototype-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k != 'layout'}, indent=2))
assert not report['page_errors'], report['page_errors']
assert not report['external_requests'], report['external_requests']
assert not failures, failures

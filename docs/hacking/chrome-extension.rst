=============================
Building the Chrome extension
=============================

You can build a local copy of the `Hypothesis Chrome extension`_ based on the
current contents of your working tree and install it in Chrome for development
or testing. To build the Chrome extension:

.. _Hypothesis Chrome extension: https://chrome.google.com/webstore/detail/hypothesis-web-pdf-annota/bjfhmglciegochdpefhhlphglcehbmek

1. Do an :doc:`h development install </hacking/install>`.

2. Build the Chrome extension locally with a fake ID.

   The ``hypothesis-buildext`` command requires the ID that Chrome will give to
   the extension for the ``--assets`` argument, but Chrome won't generate the
   ID until after you’ve built the extension and loaded it into Chrome! It's
   therefore necessary to build the extension once with a fake ID and then
   rebuild it with the correct one.

   Once it has generated an ID for your local build of the extension Chrome
   will always use the same ID (even when you rebuild and reload the
   extension), so you'll only have to do this once:

   .. code-block:: bash

      hypothesis-buildext conf/development.ini chrome
          --base   'http://127.0.0.1:5000'
          --assets 'chrome-extension://notarealid/public'

3. Go to ``chrome://extensions/`` in Chrome.

4. Tick **Developer mode**.

5. Click **Load unpacked extension**.

6. Browse to the ``h/build/chrome/`` directory where the extension was built
   and select it. Chrome will load the extension but it won't work because it
   wasn't built with the right ID (you'll see "Failed to load resource" errors
   in the Chrome Developer Tools console).

7. Copy the ID that Chrome has assigned to the loaded extension from the
   ``chrome://extensions/`` page.

8. Re-run the ``hypothesis-buildext`` command from above, replacing
   ``notarealid`` with the ID that you just copied:

   .. code-block:: bash

      hypothesis-buildext conf/development.ini chrome
          --base   'http://127.0.0.1:5000'
          --assets 'chrome-extension://oldbkmekfdjiffgkconlamcngmkioffd/public'

   (Replace ``oldbkmekfdjiffgkconlamcngmkioffd`` with your extension's ID.)

9. Go back to ``chrome://extensions/`` in Chrome and reload the page
   (:kbd:`Ctrl+R`), this will reload all your extensions.

Your extension should be working now! Remember that it communicates with your
local h instance, so you need to have h running to use the extension.

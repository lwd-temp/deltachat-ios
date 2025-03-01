# Delta Chat iOS Changelog

## v1.40.3
2023-10

* fix a crash when opening the connectivity view on newer iOS versions
* minimum system version is iOS 12 now
* using core119


## v1.40.2
2023-10

* update libwebp and other libs
* remove meet.jit.si from default video chat instances as it requires login now
* update translations
* using core119


## v1.40.0
2023-08

* improve IMAP logs
* update "verified icon"
* fix: avoid IMAP move loops when DeltaChat folder is aliased
* fix: accept webxdc updates in mailing lists
* fix: delete webxdc status updates together with webxdc instance
* fix: prevent corruption of large unencrypted webxdc updates
* fix "Member added by me" message appearing sometimes within wrong context
* fix core panic after sending 29 offline messages
* fix: make avatar in qr-codes work on more platforms
* fix: preserve indentation when converting plaintext to HTML
* fix: remove superfluous spaces at start of lines when converting HTML to plaintext
* fix: always rewrite and translate member added/removed messages
* add Luri Bakhtiari translation, update other translations and local help
* update to core119


## v1.38.2
2023-06

* improve group membership consistency
* fix verification issues because of email addresses compared case-sensitive sometimes
* fix empty lines in HTML view
* fix empty links in HTML view
* update translations
* update to core117.0


## v1.37.0 Testflight
2023-06

* view "All Media" of all chats by the corresponding button
* new "Clear Chat" option in the profiles
* remove upper size limit of attachments
* save local storage: compress HTML emails in the database
* save traffic and storage: recode large PNG and other supported image formats
  (large JPEG were always recoded; images send as "File" are still not recorded or changed otherwise)
* also strip metadata from images before sending
  in case they're already small enough and do not require recoding
* strip unicode sequences that are useless but may trick the user (RTLO attacks)
* snappier UI by various speed improvements
* sticky search result headers
* accessibility: adaptive fonts in the welcome screen
* disabled "Read" button in the archive view if there is nothing that can be marked as read
* fix a bug that avoids pinning or archiving the first search results
* fix: exiting messages are no longer downloaded after configuration
* fix: don't allow blocked contacts to create groups
* fix: do not send messages when sending was cancelled while being offline
* fix various bugs and improve logging
* fix: show errors when trying to send locations without access
* update to core116.0


## v1.36.4
2023-04

* add "Paste From Clipboard" to QR code scanner
* fix fetch errors due to erroneous EOF detection in long IMAP responses
* fix crash in search when using the app on macos
* more bug fixes
* update translations and local help
* update to core112.7


## v1.36.1
2023-03

* new, easy method of adding a second device to your account:
  scan the QR code shown at "Settings / Add Second Device" with your new device
* revamped settings dialog
* show non-deltachat emails by default for new installations
  (you can change this at "Settings / Chats and Media)
* resilience against outages by caching DNS results for SMTP connections
  (IMAP connections are already cached since 1.34.11)
* make better use of dark/light mode in "Show full message"
* prefer TLS over STARTTLS during autoconfiguration, set minimum TLS version to 1.2
* use SOCKS5 configuration also for HTTP requests
* improve speed by reorganizing the database connection pool
* improve speed by decrypting messages in parallel
* improve reliability by using read/write instead of per-command timeouts for SMTP
* improve reliability by closing databases sooner
* improve compatibility with encrypted messages from non-deltachat clients
* add menu with links to issues reporting and more to help
* fix: update mute icon in chat's title
* fix: Skip "Show full message" if the additional text is only a footer already shown in the profile
* fix verifications when using for multiple devices
* fix backup imports for backups seemingly work at first
* fix a problem with gmail where (auto-)deleted messages would get archived instead of deleted
* fix deletion of more than 32000 messages at the same time
* update provider database
* update translations
* update to core112.4


## v1.35.0 Testflight
2023-02

* show non-deltachat emails by default for new installations
* add jumbomoji support: messages containing only emoji shown bigger
* verified marker shown right of the chat names now
* show hint on successful backups
* add option to copy QR codes to the clipboard
* show full messages: do not load remote content for requests automatically
* improve freeing of unused space
* cache DNS results for SMTP connections
* use read/write timeouts instead of per-command timeouts for SMTP
* prefer TLS over STARTTLS during autoconfiguration
* fix Securejoin for multiple devices on a joining side
* fix closing of database files, allowing proper shutdowns
* fix some database transactions
* fix a problem with Gmail where (auto-)deleted messages would get archived instead of deleted.
  Move them to the Trash folder for Gmail which auto-deletes trashed messages in 30 days
* fix: clear config cache after backup import. This bug sometimes resulted in the import to seemingly work at first
* speed up connections to the database
* improve logging
* update translations
* update to core110


## v1.34.12
2023-02

* disable SMTP pipelining for now
* improve logging
* update to core107.1


## v1.34.11
2023-01

* introduce DNS cache: if DNS stops working on a network,
  Delta Chat will still be able to connect to IMAP by using previous IP addresses
* speed up sending and improve usability in flaky networks by using SMTP pipelining
* show a dialog on backup success
* allow ogg attachments being shared to apps that can handle them
* add "Copy to Clipboard" option for mailing list addresses
* fix wrong counters shown in gallery sometimes
* fix SOCKS5 connection handling
* fix various bugs and improve logging
* update translations
* update to core107


## v1.34.10
2023-01

* fix: make archived chats visible that don't get unarchived automatically (muted chats):
  add an unread counter and move the archive to the top
* fix: send AVIF, HEIC, TXT, PPT, XLS, XML files as such
* fix: trigger reconnection when failing to fetch existing messages
* fix: do not retry fetching existing messages after failure, prevents infinite reconnection loop
* fix: do not add an error if the message is encrypted but not signed
* fix: do not strip leading spaces from message lines
* fix corner cases on sending quoted texts
* fix STARTTLS connection
* fix: do not treat invalid email addresses as an exception
* fix: flush relative database paths introduced in 1.34.8 in time
* prefer document name over webxdc name for home screen icons
* faster updates of chat lists and contact list
* update translations
* update to core106


## v1.34.8
2022-12

* If a classical-email-user sends an email to a group and adds new recipients,
  the new recipients will become group members
* treat attached PGP keys from classical-email-user as a signal to prefer mutual encryption
* treat encrypted or signed messages from classical-email-user as a signal to prefer mutual encryption
* VoiceOver: improve navigating through messages
* fix migration of old databases
* fix: send ephemeral timer change messages only of the chat is already known by other members
* fix: use relative paths to database and avoid problems eg. on migration to other devices or paths
* fix read/write timeouts for IMAP over SOCKS5
* fix: do not send "group name changes" if no character was modified
* add Greek translation, update other translations
* update to core104


## v1.34.7 Testflight
2022-12

* show audio recorder on half screen
* prevent From:-forgery attacks
* disable Autocrypt & Authres-checking for mailing lists because they don't work well with mailing lists
* small speedups
* improve logging
* fix crash on copy message with iOS 14.8
* fix detection of "All mail", "Trash", "Junk" etc folders
* fix reactions on partially downloaded messages by fetching messages sequentially
* fix a bug where one malformed message blocked receiving any further messages
* fix: set read/write timeouts for IMAP over SOCKS5
* update translations
* update to core103


## v1.34.6 Testflight
2022-11

* improve account switcher: use the icon atop the chatlist to switch, add and edit accounts
* allow removal of references contacts from the "New Chat" list
* show icon beside webxdc info messages
* show more debug info in message info, improve logging
* add default video chat instances
* VoiceOver: read out unread messages in account switch button and account switch view controller
* VoiceOver: improve order of read out content in chatlist
* fix muted VoiceOver after recording voice message
* fix: support mailto:-links in full-message-view
* fix direct share usage with multiple accounts
* fix emojis in webxdc
* fix potential busy loop freeze when marking messages as seen
* fix: suppress welcome messages after account import
* fix: apply language changes to all accounts
* fix chatlist's multi-edit "Cancel" button
* fix images for webxdc using the phaser library
* update translations and local help
* update to core101


## v1.34.1
2022-10

* show the currently selected account in the chatlist;
  a tap on it shows the account selector dialog
* show a "recently seen" dot on avatars if the contact was seen within ten minutes
* order contact and members lists by "last seen"
* support drag'n'drop to delta chat: eg. long tap an image from the system gallery
  and _with a second finger_ navigate to Delta Chat and then to the desired chat
* improve multi-select of messages: add "Copy to Clipboard", show selection count
* allow resending of messages from multi-select
* backup import: allow selection of different backups by a file selector
* show mailing list addresses in profile
* user friendlier system messages as "You changed the group image."
* allow replying with a voice message
* introduce a "Login" QR code that can be generated by providers for easy log in
* allow scanning of "Accounts" and "Logins" QR codes using system camera
* connectivity view shows disabled "Low Data Mode"/"Low Power Mode" as possible cause of problems
* truncate incoming messages by lines instead of just length
* for easier multi device setup, "Send Copy To Self" is enabled by default now
* add webxdc's to the home screen from the webxdc's menu,
  allowing easy access and integration
* add a webxdc selector to the "Attach" menu (the paperclip in message view)
* bigger avatar in message view title
* larger, easier to tap search and mute buttons in profiles
* fix: show gallery's "back" button on iOS 16
* fix: mark "group image changed" as system message on receiver side
* fix: improved error handling for account setup from QR code
* fix: do not emit notifications for blocked chats
* fix: show attached .eml files correctly
* fix: don't prepend the subject to chat messages in mailing lists
* fix: reject webxdc updates from contacts who are not group members
* fix memory leak on account switching
* update translations
* update to core95


## v1.32.0
2022-07

* show post address in mailinglist's profile
* AEAP: show confirmation dialog before changing e-mail address
* AEAP: add a device message after changing e-mail address
* AEAP replaces e-mail addresses only in verified groups for now
* fix opening experimental encrypted accounts
* fix: handle updates for not yet downloaded webxdc instances
* fix: better information on several configuration and non-delivery errors
* fix accessibility hint in multi-select chat list title
* update translations, revise english source
* update to core90


## v1.31.0 Testflight
2022-07

* experimental "Automatic E-mail Address Porting" (AEAP):
  You can configure a new address now, and when receivers get messages
  they will automatically recognize your moving to a new address
* multi-select in chat list: long-tap a chat and select more chats
  for deletion, pinning or archiving
* add 'reply privately' option to group chats
* add search to full-message-views and help
* make bot-commands such as /echo clickable
* adapt document gallery view to system text size
* cleanup series of webxdc-info-messages
* show document and chat name in webxdc titles
* add menu entry access the webxdc's source code
* send normal messages with higher priority than read receipts
* improve chat encryption info, make it easier to find contacts without keys
* improve error reporting when creating a folder fails
* allow mailto: links in webxdc
* combine read receipts and webxdc updates and avoid sending too many messages
* message lines starting with `>` are sent as quotes to non-Delta-Chat clients
* support IMAP ID extension that is required by some providers
* disable gesture to close webxdc to avoid confusion with gestures inside webxdc
* show webxdc icon in quoted webxdc messages
* info messages can be selected in multi-select
* fix: make chat names always searchable
* fix: do not reset database if backup cannot be decrypted
* fix: do not add legacy info-messages on resending webxdc
* fix: let "Only Fetch from DeltaChat Folder" ignore other folders
* fix: Autocrypt Setup Messages updates own key immediately
* fix: do not skip Sent and Spam folders on gmail
* fix: cleanup read-receipts saved by gmail to the Sent folder
* fix: handle decryption errors explicitly and don't get confused by encrypted mail attachments
* fix: repair encrypted mails "mixed up" by Google Workspace "Append footer" function
* fix: use same contact-color if email address differ only in upper-/lowercase
* fix scroll-down button visibility
* fix: allow DeltaChat folder being hidden
* fix: cleanup read receipts storage
* fix: mailing list: remove square-brackets only for first name
* fix: do not use footers from mailinglists as the contact status
* update provider database, add hermes.radio subdomains
* update translations
* update to core88


## v1.30.1
2022-05

* speed up loading of chat messages by a factor of 20
* speed up finding the correct server after logging in
* speed up marking messages as being seen and use fewer network data by batch processing
* speed up messages deletion and use fewer network data for that
* speed up message receiving a bit
* speed up various parts by caching config values
* speed up chat list loading massively
* speed up checking for new messages in background
* revamped welcome screen
* archived+muted chats are no longer unarchived when new messages arrive;
  this behavior is also known by other messengers
* improve voice-over navigation in chat
* add support for webxdc messages
* fix: do not create empty contact requests with "setup changed" messages;
  instead, send a "setup changed" message into all chats we share with the peer
* fix an issue where the app crashes when trying to export a backup
* fix outgoing messages appearing twice with Amazon SES
* fix unwanted deletion of messages that have no Message-ID set or are duplicated otherwise
* fix: assign replies from a different email address to the correct chat
* fix: assign outgoing private replies to the correct chat
* fix: ensure ephemeral timer is started eventually also on rare states
* fix: do not try to use stale SMTP connections
* fix: retry message sending automatically and do not wait for the next message being sent
* fix a bug where sometimes the file extension of a long filename containing a dot was cropped
* fix messages being treated as spam by placing small MIME-headers before the larger Autocrypt:-header
* fix: keep track of QR code joins in database to survive restarts
* fix: automatically accept chats with outgoing messages
* fix connectivity view's "One moment..." message being stuck when there is no network
* fix: select Chinese Traditional and Chinese Simplified accordingly
* fix several issues when checking for new messages in background
* fix: update chat when adding something from the share-extension
* fix scroll-down button not always appearing as expected
* fix: connect to notification service as soon as possible even if there is no network on initial startup
* fix: disable zoom in connectivity view
* fix layout of info-messages in dark-mode
* fix: show download failures
* fix: send locations in the background regardless of other sending activity
* fix rare crashes when stopping IMAP and SMTP
* fix correct message escaping consisting of a dot in SMTP protocol
* fix rendering of quotes in QR code descriptions
* fix: accessibility: do not stop VoiceOver output after sending a voice-message
* various improvements for the VoiceOver navigation in a chat
* fixed memory leaks in chats
* fix wallpaper disappearing sometimes
* fix app crash after providing camera permissions
* fix: allow playing voice messages in background
* fix some scrolling issues in chat view
* fix multi-select message layout (time was sometimes truncated)
* add finnish translation, update other translations
* update provider database
* update to core80


## v1.28.1
2022-02

* fix some missing chatlist updates
* update translations


## v1.28.0
2022-01

* add option to create encrypted database at "Add Account",
  the database passphrase is generated automatically and is stored in the system's keychain,
  subsequent versions will probably get more options to handle passphrases
* add writing support for supported mailinglist types; other mailinglist types stay read-only
* add an option to define a background image that is used in all chats then :)
* "Message Info" show routes
* add option "Your Profile Info / Password and Account / Only Fetch from DeltaChat Folder";
  this is useful if you can configure your server to move chat messages to the DeltaChat folder
* add "Search" and "Mute" as separate buttons to the chat profiles
* the connectivity status now also shows if notifications work as expected
* improve accessibility for the chat requests button bar
* semi-transparent chat input bar at the bottom of the chat view
* show chat title in delete confirmation dialog
* speed up opening chats
* explicit "Watch Inbox folder" and "Watch DeltaChat folder" settings no longer required;
  the folders are watched automatically as needed
* to safe traffic and connections, "Advanced / Watch Sent Folder" is disabled by default;
  as all other IMAP folders, the folder is still checked on a regular base
* detect correctly signed messages from Thunderbird and show them as such
* synchronize Seen status across devices
* more reliable group memberlist and group avatar updates
* recognize MS Exchange read receipts as such
* fix leaving groups
* fix unread count issues in account switcher
* fix scroll-down button for chat requests
* fix layout issues of the chat message input bar in phone's landscape orientation
* add Bulgarian translations, update other translations and local help
* update provider-database
* update to core75


## v1.26.2
2021-12

* re-layout all QR codes and unify appearance among the different platforms
* show when a contact was "Last seen" in the contact's profile
* group creation: skip presetting a draft that is deleted most times anyway
* auto-generated avatars are displayed similar across all platforms now
* speed up returning to chat list
* fix chat assignment when forwarding
* fix group-related system messages appearing as normal messages in multi-device setups
* fix removing members if the corresponding messages arrive disordered
* fix potential issue with disappearing avatars on downgrades
* update translations
* update to core70


## v1.24.5
2021-11

* fix missing stickers, image and video messages on iOS 15
* fix "copy to clipboard" for video chat invites
* update translations
* using core65


## v1.24.4
2021-11

* fix accidental disabling of ephemeral timers when a message is not auto-downloaded
* fix: apply existing ephemeral timer also to partially downloaded messages;
  after full download, the ephemeral timer starts over
* update translations and local help
* update to core65


## v1.24.3
2021-11

* fix messages added on scanning the QR code of an contact
* fix incorrect assignment of Delta Chat replies to classic email threads
* update translations and local help


## v1.24.1
2021-11

* new "In-Chat Search" added; tap the corresponding option in the profile
* new option "Auto-Download Messages": Define the max. messages size to be downloaded automatically -
  larger messages, as videos or large images, can be downloaded manually by a simple tap then
* new: much easier joining of groups via qr-code: nothing blocks
  and you get all progress information in the immediately created group
* new: get warnings before your server runs out of space (if quota is supported by your provider)
* messages are marked as "being read" already when the first recipient opened the message
  (before, that requires 50% of the recipients to open the message)
* contact requests are notified as usual now
* add an option to copy a contact's email address to the clipboard
* force strict certificate checks when a strict certificate was seen on first login
* do not forward group names on forwarding messages
* "Broadcast Lists", as known from other messengers, added as an experimental feature
  (you can enable it at "Settings / Advanced")
* fix: disappearing messages timer now synced more reliable in groups
* fix: improve detection of some mailing list names
* fix "QR process failed" error
* fix DNS and certificate issues
* fix: if account creation was aborted, go to the previously selected account, not to the first
* fix: update app badge counter on archiving a chat directly
* fix: reduce memory consumption of share extension
* fix: update search result when messages update
* fix requesting camera permissions on some devices
* fix: use correct margins on phones with a notch
* fix: update chat profile when chat changes remotely
* fix: no more screen flickering when deleting a chat
* update provider-database
* update translations and local help


## v1.22.1
2021-08

* fix: always reconnect if account creation was cancelled
* update translations


## v1.22.0
2021-08

* added: connectivity view shows quota information, if supported by the provider
* fix account migration, updates are displayed instantly now
* fix forwarding mails containing only quotes
* fix ordering of some system messages
* fix handling of gmail labels
* fix connectivity display for outgoing messages
* fix acceping mailing lists
* fix drafts popping up as message bubbles
* fix connectivity info updates
* update translations and provider database


## v1.21.1 Testflight
2021-08

* fix: avoid possible data loss when the app was not closed gracefully before;
  this bug was introduced in 1.21.0 and not released outside testing groups -
  thanks to all testers!


## 1.21.0 Testflight
2021-07

* added: multi-account functionality: add and switch accounts from the settings
* added: every new "contact request" is shown as a separate chat now,
  you can block or accept or archive or pin them
  (old contact requests are available in "Archived Chats")
* added: the title bar shows if the app is not connected
* added: a tap in the title bar shows connectivity details (also available in settings)
* added: allow defining a video chat instance (eg. any jitsi instance)
* added: send video chat invites
* added: receive video chat invites as such
* added: offer a button for quick scrolling down in a chat
* deactivate and reactivate your own QR codes by just scanning them
* quotes can now refer messages from other chats
* do not show signature in "Saved Messages"
* revert sharing webp files as stickers
* fix date labels stuck in the seventies sometimes
* fix "show in chat"
* fix sharing issues
* fix: crash in gallery
* fix message input bar and share layout for iPad
* fix: keep keyboard open after cancelling drafts and quotes 
* fix displaying of small images
* fix more scrolling issues


## 1.20.5
2021-06

* show status/footer messages in contact profiles
* show stickers as such
* send memojis as stickers
* open chat at the first unread message
* fix downscaling images
* fix outgoing messages popping up in "Saved messages" for some providers
* fix: do not allow deleting contacts with ongoing chats
* fix: ignore drafts folder when scanning
* fix: scan folders also when inbox is not watched
* fix scrolling issues
* fix: not not stack chats on tapping notifications
* fix: show warning if camera access is denied
* fix: do not hide keyboard after sending a message
* fix: hide keyboard when tapping on a search result
* improve error handling and logging
* update translations, local help and provider database


## 1.20.4
2021-05

* fix: remove notifications if the corresponding chat is archived
* fix: less 0xdead10cc exceptions, mark background threads as such
* update translations


## 1.20.3
2021-05

* fix "show in chat" function in profile's gallery and document views
* fix: less 0xdead10cc exceptions in background
* update dependencies
* update translations


## 1.20.2
2021-05

* show total playback time of audio files before starting playback
* show location icon beside messages containing locations
* improve layout of delivery information inside bubbles
* fix: do not start location manager when location streaming is disabled
* fix: do not send read receipts when the screen is off
* fix: delete notifications if the corresponding chat is deleted
* fix: target background issues
* fix crash when receiving some special messages                                
* fix downloading some messages multiple times                                  
* fix formatting of read receipt texts  
* update translations


## 1.20.0
2021-05

* opening the contact request chat marks all contact requests as noticed
  and removes the sticky hint from the chatlist
* if "Show classic mails" is enabled,
  the contact request hint in the corresponding chat
* speed up global search
* improve display of small images
* fix: filter contact list for adding members to verified groups
* fix: re-add headlines for every day
* fix: register for notifications also after qr-code account scanning
* fix a rare crash on chat deletion
* fix: update chat on forwarding to saved-messages
* fix: make links and default user actions work in contact requests
* add Chinese, French, Indonesian, Polish and Ukrainian local help, update other translations


## 1.19.1 Testflight
2021-04

* speed improvements
* fix a rare crash in chatlist


## 1.19.0 Testflight
2021-04

* show answers to generic support-addresses as info@company.com in context
* allow different sender for answers to support-addresses as info@company.com
* show multiple notifications
* group notifications by chats
* speed up chatlist update and global search
* improve detection of quotes
* improve background fetching
* ignore classical mails from spam-folder
* make log accessible on configure at "Log in to your Server / Advanced"
* fix showing configure errors
* add Czech translation, update other translations


## 1.17.1 Testflight
2021-03

* new mailinglist and better bot support
* more reliable notifications about every 20 minutes, typically faster
* tapping notification opens the corresponding chat
* more information and images shown in notifications
* add option to view original-/html-mails
* check all imap folders for new messages from time to time
* allow dialing on tapping a phone number
* use more colors for user avatars
* improve e-mail compatibility
* improve animations and scrolling
* improve compatibility with Outlook.com
  and other providers changing message headers
* scale avatars based on media_quality, fix avatar rotation
* export backups as .tar files
* enable strict TLS for known providers by default
* improve and harden secure join
* show warning for unsupported audio formats
* fix send button state after video draft has been added
* fix background crash
* fix read receipts
* fix decoding of attachment filenames
* fix: exclude muted chats from notified-list
* fix: do not return quoted messages from the trash chat
* much more bug fixes
* add Khmer, Persian, Arabic, Kurdish, Sardinian translations, update other translations
* add Czech local help, update other local help


## 1.16.0
2021-02

* new staging area: images and other files
  can be reviewed and sent together with a description now
* show in chat: go to the the corresponding message
  directly from images or documents in the gallery
* new, redesigned context menus in chat, gallery and document view -
  long-tap a message to feel the difference
* multi-select in chat: long-tap a message and select more messages
  for deletion or forwarding
* improve several accessibility items and texts
* improve keyboard layouts
* fix: profile images can now always be cropped after selection
* fix: hints in empty chats are no longer truncated
* fix swipe-to-reply icon for iOS 11 and 12
* more bug fixes
* update translations and local help


## 1.14.4
2020-12

* fix scrolling bug on ios 14.2
* update translations


## 1.14.3
2020-11

* fix bug that could lead to empty messages being sent
* update translations


## 1.14.2
2020-11

* fix issues when combining bubbles of the same sender
* update translations


## 1.14.1
2020-11

* new swipe-to-reply option
* show impact of the "Delete messages from server" option more clearly
* fix: do not fetch from INBOX if "Watch Inbox folder" is disabled
  and do not fetch messages arriving before re-enabling
* fix: do not use STARTTLS when PLAIN connection is requested
  and do not allow downgrade if STARTTLS is not available
* fix: make "nothing found" hints always visible
* fix: update selected avatars immediately
* update translations


## 1.14.0
2020-11

* disappearing messages: select for any chat the lifetime of the messages
* scroll chat to search result
* fast scrolling through all chat-messages by long tapping the scrollbar
* show quotes in messages as such
* add known contacts from the IMAP-server to the local addressbook on configure
* enable encryption in groups if preferred by the majority of recipients
  (previously, encryption was only enabled if everyone preferred it)
* speed up configuration
* try multiple servers from autoconfig
* check system clock and app date for common issues
* improve multi-device notification handling
* improve detection and handling of video and audio messages
* hide unused functions in "Saved messages" and "Device chat" profiles
* bypass some limits for maximum number of recipients
* add option to show encryption info for a contact
* fix launch if there is an ongoing process
* fix errors that are not shown during configuring
* fix mistakenly unarchived chats
* fix: tons of improvements affecting sending and receiving messages, see
  https://github.com/deltachat/deltachat-core-rust/blob/master/CHANGELOG.md
* update provider database and dependencies
* add Slovak translation, update other translations


## 1.12.3
2020-08

* allow importing backups in the upcoming .tar format
* remove X-Mailer debug header
* try various server domains on configuration
* improve guessing message types from extension
* improve member selection in verified groups
* fix threading in interaction with non-delta-clients
* fix showing unprotected subjects in encrypted messages
* more fixes, update provider database and dependencies


## 1.12.2
2020-08

* add last chats to share suggestions
* fix improvements for sending larger mails
* fix a crash related to muted chats
* fix incorrect dimensions sometimes reported for images
* improve linebreak-handling in HTML mails
* improve footer detection in plain text email
* fix deletion of multiple messages
* more bug fixes


## 1.12.0
2020-07

* use native camera, improve video recording
* streamline profile views and show the number of items
* option to enlarge profile image
* show a device message when the password was changed on the server
* show experimental disappearing-messages state in chat's title bar
* improve sending large messages and GIF messages
* improve receiving messages
* improve error handling when there is no network
* allow avatar deletion in profile and in groups
* fix gallery dark-mode
* fix login issue on ios 11
* more bug fixes


## 1.10.1
2020-07

* new launchscreen
* improve overall stability
* improve message processing
* disappearing messags added as an experimental feature


## 1.10.0
2020-06

* with this version, Delta Chat enters a whole new level of speed,
  messages will be downloaded and sent way faster -
  technically, this was introduced by using so called "async-processing"
* share images and other content from other apps to Delta Chat
* show animated GIF directly in chat
* reworked gallery and document view
* select outgoing media quality
* mute chats
* if a message cannot be delivered to a recipient
  and the server replies with an error report message,
  the error is shown beside the message itself in more cases
* default to "Strict TLS" for some known providers
* improve reconnection handling
* improve interaction with conventional email programs
  by showing better subjects
* improve adding group members
* fix landscape appearance
* fix issues with database locking
* fix importing addresses
* fix memory leaks
* more bug fixes


## v1.8.1
2020-05

* add option for automatic deletion of messages after a given timespan;
  messages can be deleted from device and/or server
* switch to ecc keys; ecc keys are much smaller and faster
  and safe traffic and time this way
* new welcome screen
* add an option to create an account by scanning a qr code, of course,
  this has to be supported by the used provider
* rework qr-code scanning: there is now one view with two tabs
* improve interaction with traditional mail clients
* improve avatar handling on ipad
* debug and log moved to "Settings / Advanced / View log"
* bug fixes
* add Indonesian translation, update other translations


## v1.3.0
2020-03-26

* add global search for chats, contacts, messages - just swipe down in the chatlist
* show padlock beside encrypted messages
* tweak checkmarks for "delivered" and "read by recipient"
* add option "Settings / Advanced / On-demand location streaming" -
  once enabled, you can share your location with all group members by
  taping on the "Attach" icon in a group
* add gallery-options to chat-profiles
* on forwarding, "Saved messages" will be always shown at the top of the list
* streamline confirmation dialogs on chat creation and on forwarding to "Saved messages"
* faster contact-suggestions, improved search for contacts
* improve interoperability eg. with Cyrus server
* fix group creation if group was created by non-delta clients
* fix showing replies from non-delta clients
* fix crash when using empty groups
* several other fixes
* update translations and help


## v1.2.1
2020-03-04

* on log in, for known providers, detailed information are shown if needed;
* in these cases, also the log in is faster
  as needed settings are available in-app
* save traffic: messages are downloaded only if really needed,
* chats can now be pinned so that they stay sticky atop of the chat list
* integrate the help to the app
  so that it is also available when the device is offline
* a 'setup contact' qr scan is now instant and works even when offline -
  the verification is done in background
* unified 'send message' option in all user profiles
* rework user and group profiles
* add options to manage keys at "Settings/Autocrypt/Advanced"
* fix updating names from incoming mails
* fix encryption to Ed25519 keys that will be used in one of the next releases
* several bug fixes, eg. on sending and receiving messages, see
  https://github.com/deltachat/deltachat-core-rust/blob/master/CHANGELOG.md#1250
  for details on that
* add Croatian and Esperanto translations, update other translations

The changes have been done by Alexander Krotov, Allan Nordhøy, Ampli-fier,
Angelo Fuchs, Andrei Guliaikin, Asiel Díaz Benítez, Besnik, Björn Petersen,
ButterflyOfFire, Calbasi, cloudieg, Dmitry Bogatov, dorheim, Emil Lefherz,
Enrico B., Ferhad Necef, Florian Bruhin, Floris Bruynooghe, Friedel Ziegelmayer,
Heimen Stoffels, Hocuri, Holger Krekel, Jikstra, Lin Miaoski, Moo, nayooti,
Nico de Haen, Ole Carlsen, Osoitz, Ozancan Karataş, Pablo, Paula Petersen,
Pedro Portela, polo lancien, Racer1, Simon Laux, solokot, Waldemar Stoczkowski,
Xosé M. Lamas, Zkdc


## v1.1.1
2020-02-02

* fix string shown on requesting permissions


## v1.1.0
2020-01-29

* add a document picker to allow sending files
* show video thumbnails
* support memoji and other images pasted from the clipboard
* improve image quality
* reduce traffic by combining read receipts and some other tweaks
* fix deleting messages from server
* add Korean, Serbian, Tamil, Telugu, Svedish and Bokmål translations
* several bug fixes


## v1.0.2
2020-01-09

* fix crashes on iPad


## v1.0.1
2020-01-07

* handle various qr-code formats
* allow creation of verified groups
* improve wordings on requesting permissions
* bug fixes


## v1.0.0
2019-12-23

Finally, after months of coding and fixing bugs, here it is:
Delta Chat for iOS 1.0 :)

* support for user avatars: select your profile image
  at "settings / my profile info"
  and it will be sent out to people you write to
* previously selected avatars will not be used automatically,
  you have to select a new avatar
* introduce a new "Device Chat" that informs the user about app changes
  and, in the future, problems on the device
* rename the "Me"-chat to "Saved messages",
  add a fresh icon and make it visible by default
* update translations
* bug fixes

The changes of this version and the last beta versions have been done by
Alexander Krotov, Allan Nordhøy, Ampli-fier, Andrei Guliaikin,
Asiel Díaz Benítez, Besnik, Björn Petersen, ButterflyOfFire, Calbasi, cyBerta,
Daniel Boehrsi, Dmitry Bogatov, dorheim, Emil Lefherz, Enrico B., Ferhad Necef,
Florian Bruhin, Floris Bruynooghe, Friedel Ziegelmayer, Heimen Stoffels, Hocuri,
Holger Krekel, Jikstra, Lars-Magnus Skog, Lin Miaoski, Moo, Nico de Haen,
Ole Carlsen, Osoitz, Ozancan Karataş, Pablo, Pedro Portela, polo lancien,
Racer1, Simon Laux, solokot, Waldemar Stoczkowski, Xosé M. Lamas, Zkdc


## v0.960.0
2019-11-24

* allow picking a profile-image for yourself;
  the image will be sent to recipients in one of the next updates:
* streamline group-profile and advanced-loging-settings
* show 'Automatic' for unset advanced-login-settings
* show used settings below advanced-login-setting
* add global option to disable notifications
* update translations
* various bug fixes


## v0.950.0
2019-11-05

* move folder settings to account settings
* improve scanning of qr-codes
* update translations
* various bug fixes


## v0.940.2
2019-10-31

* add "dark mode" for all views
* if a message contains an email, this can be used to start a chat directly
* add "delete mails from server" options
  to "your profile info / password and account"
* add option to delete a single message
* if "show classic emails" is set to "all",
  emails pop up as contact requests directly in the chatlist
* update translations
* various bug fixes


## v0.930.0
2019-10-22

* add "send copy to self" switch
* play voice messages and other audio
* show descriptions for images, video and other files
* show correct delivery states
* show forwarded messages as such
* improve group editing
* show number of unread messages
* update translations
* various bug fixes


## v0.920.0
2019-10-10

* show text sent together with images or files
* improve onboarding error messages
* various bug fixes


## v0.910.0
2019-10-07

* after months of hard work, this release is finally
  based on the new rust-core that brings improved security and speed,
  solves build-problems and also makes future developments much easier.
  there is much more to tell on that than fitting reasonably in a changelog :)
* start writing a changelog
* hide bottom-bar in subsequent views
* fix a bug that makes port and other advaced settings unchangeable after login
* disable dark-mode in the chat view for now
* update translations

The changes have been done Alexander Krotov, Andrei Guliaikin,
Asiel Díaz Benítez, Besnik, Björn Petersen, Calbasi, cyBerta, Dmitry Bogatov,
dorheim, Enrico B., Ferhad Necef, Florian Bruhin, Floris Bruynooghe,
Friedel Ziegelmayer, Heimen Stoffels, Hocuri, Holger Krekel, Jikstra,
Jonas Reinsch, Lars-Magnus Skog, Lin Miaoski, Moo, nayooti, Ole Carlsen,
Osoitz, Ozancan Karataş, Pedro Portela, polo lancien, Racer1, Simon Laux,
solokot, Waldemar Stoczkowski, Zkdc  

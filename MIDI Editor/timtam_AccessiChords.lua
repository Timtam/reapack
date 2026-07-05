-- @metapackage
-- @version 1.3
-- @description AccessiChords
-- @author Toni Barth (Timtam), Scott Chesworth
-- @links
--   GitHub repository https://github.com/Timtam/AccessiChords
--   Donation https://paypal.me/ToniRonaldBarth
-- @provides
--   [nomain] timtam_AccessiChords/smallfolk.lua https://github.com/Timtam/AccessiChords/raw/v$version/timtam_AccessiChords/smallfolk.lua
--   [main=midi_editor] timtam_AccessiChords/timtam_AccessiChords insert selected chord for pitch cursor.lua https://github.com/Timtam/AccessiChords/raw/v$version/timtam_AccessiChords/timtam_AccessiChords%20insert%20selected%20chord%20for%20pitch%20cursor.lua
--   [main=midi_editor] timtam_AccessiChords/timtam_AccessiChords move to next chord.lua https://github.com/Timtam/AccessiChords/raw/v$version/timtam_AccessiChords/timtam_AccessiChords%20move%20to%20next%20chord.lua
--   [main=midi_editor] timtam_AccessiChords/timtam_AccessiChords move to previous chord.lua https://github.com/Timtam/AccessiChords/raw/v$version/timtam_AccessiChords/timtam_AccessiChords%20move%20to%20previous%20chord.lua
--   [main=midi_editor] timtam_AccessiChords/timtam_AccessiChords process notes deferred.lua https://github.com/Timtam/AccessiChords/raw/v$version/timtam_AccessiChords/timtam_AccessiChords%20process%20notes%20deferred.lua
--   [main=midi_editor] timtam_AccessiChords/timtam_AccessiChords select next chord for pitch cursor.lua https://github.com/Timtam/AccessiChords/raw/v$version/timtam_AccessiChords/timtam_AccessiChords%20select%20next%20chord%20for%20pitch%20cursor.lua
--   [main=midi_editor] timtam_AccessiChords/timtam_AccessiChords select next chord inversion.lua https://github.com/Timtam/AccessiChords/raw/v$version/timtam_AccessiChords/timtam_AccessiChords%20select%20next%20chord%20inversion.lua
--   [main=midi_editor] timtam_AccessiChords/timtam_AccessiChords select next chord mode.lua https://github.com/Timtam/AccessiChords/raw/v$version/timtam_AccessiChords/timtam_AccessiChords%20select%20next%20chord%20mode.lua
--   [main=midi_editor] timtam_AccessiChords/timtam_AccessiChords select previous chord for pitch cursor.lua https://github.com/Timtam/AccessiChords/raw/v$version/timtam_AccessiChords/timtam_AccessiChords%20select%20previous%20chord%20for%20pitch%20cursor.lua
--   [main=midi_editor] timtam_AccessiChords/timtam_AccessiChords select previous chord inversion.lua https://github.com/Timtam/AccessiChords/raw/v$version/timtam_AccessiChords/timtam_AccessiChords%20select%20previous%20chord%20inversion.lua
--   [main=midi_editor] timtam_AccessiChords/timtam_AccessiChords select previous chord mode.lua https://github.com/Timtam/AccessiChords/raw/v$version/timtam_AccessiChords/timtam_AccessiChords%20select%20previous%20chord%20mode.lua
--   [nomain] timtam_AccessiChords/timtam_AccessiChords.lua https://github.com/Timtam/AccessiChords/raw/v$version/timtam_AccessiChords/timtam_AccessiChords.lua
-- @changelog
--   * expand chord library with 17 extra voicings and regroup by family
--   * clean up speech output
--   * add move-to-chord actions that report the chord in AccessiChords' voice
-- @about
--   <!-- taken from Best-README-Template
--   <!-- https://github.com/othneildrew/Best-README-Template
--   <!-- PROJECT SHIELDS -->
--   <!--
--   *** I'm using markdown "reference style" links for readability.
--   *** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
--   *** See the bottom of this document for the declaration of the reference variables
--   *** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
--   *** https://www.markdownguide.org/basic-syntax/#reference-style-links
--   -->
--   [![Contributors][contributors-shield]][contributors-url]
--   [![Forks][forks-shield]][forks-url]
--   [![Stargazers][stars-shield]][stars-url]
--   [![Issues][issues-shield]][issues-url]
--   [![GNU GPL v3 License][license-shield]][license-url]



--   <!-- PROJECT LOGO -->
--   <br />
--   <p align="center">
--     <h3 align="center">AccessiChords</h3>

--     <p align="center">
--       Accessible chord injection scripts for REAPER
--       <br />
--       <a href="https://github.com/Timtam/AccessiChords/issues">Report Bug</a>
--       ?
--       <a href="https://github.com/Timtam/AccessiChords/issues">Request Feature</a>
--     </p>
--   </p>



--   <!-- TABLE OF CONTENTS -->
--   ## Table of Contents

--   * [About the Project](#about-the-project)
--     * [Built With](#built-with)
--   * [Getting Started](#getting-started)
--   * [Usage](#usage)
--   * [Roadmap](#roadmap)
--   * [Contributing](#contributing)
--   * [License](#license)
--   * [Contact](#contact)



--   <!-- ABOUT THE PROJECT -->
--   ## About The Project

--   Chords are an important, if not the most important part of music. As soon as you're composing a piece of music in REAPER, you'll come across chords and will have to insert them into your MIDI editor. No problem if you are able to play them with your favourite MIDI controller, but more of a hassle when programming your music manually via keyboard, or if you are unable to play an instrument. 

--   Thats probably the reason why the [ChordGun scripts][chordgun-url] where invented. Those were ment to provide a nice-looking interface and the ability to get a quick overview over all chords available and the possibility to quickly shoot them into your project whenever you need them.

--   Unfortunately though, those ChordGun scripts are not accessible for visually impaired users. The interface is not accessible at all, neither with JAWS nor NVDA, not under Mac nor Windows. Thats why I started this project. Let AccessiChords be the successor of ChordGun - at least for VI people.

--   As such, AccessiChords provides a way to quickly access all chords related to a note selected with the pitch cursor and inject them into your MIDI editor at the current position and with the given grid size. See [Usage](#usage) for more information.

--   ### Built With

--   * [Lua 5.3](https://www.lua.org/manual/5.3/)
--   * [REAPER 6.13 and above (older versions might run as well)](https://reaper.fm)
--   * [OSARA nightly build as of Sep 4 or later](https://osara.reaperaccessibility.com/snapshots/)

--   <!-- GETTING STARTED -->
--   ## Getting Started

--   ### Installation

--   #### ReaPack

--   It is recommended to get the latest stable version from ReaPack by synchronizing your repositories and searching for AccessiChords in the package list. This will make sure to add all the available actions to your actions list as well.

--   #### Building from source

--   ##### Clone

--   If you thus instead want to test the bleeding edge build of this package, clone this repository locally:

--   ```sh
--   git clone https://github.com/Timtam/AccessiChords.git
--   ```

--   Copy the timtam_AccessiChords folder into your REAPER's scripts folder afterwards.

--   note: make sure to copy the folder directly into your Scripts folder, not in some other sub-folder or a totally different directory to make sure that the scripts work directly.

--   ##### Adding actions

--   Open an empty project within REAPER and open the actions list (shortcut: F4). Make sure to filter for MIDI Editor so that the actions will not be accessible from outside that one.
--   Now select New Action and Load ReaScript. Make sure to load every timtam_AccessiChords file from within the timtam_AccessiChords folder, except the one that is called timtam_AccessiChords.lua. That one only contains dependencies and doesn't contain any action. Also do not load the smallfolk.lua file, that one is not required as an action.

--   After loading the actions, run "timtam_AccessiChords process notes deferred.lua" once from the actions list. When loaded manually like this (rather than installed via ReaPack) it is assigned a different command id, so it records that id for itself on this first run. Without this step, chord playback would report that the action to process notes deferred could not be found. ReaPack installs do this automatically and don't require the manual run.

--   ### Assigning shortcuts

--   After installing the scripts in either of the ways above, you will have the actions provided by AccessiChords available in your actions list to be used.
--   I however recommend to assign shortcuts to them to speed up the workflow and productivity with this toolset.
--   Therefore, open the actions list again and search for AccessiChords in the filter input. I'd recommend the following shortcuts for the corresponding actions, although that's up to personal preference and you can assign them as you see fit:

--   * timtam_AccessiChords insert selected chord for pitch cursor.lua: Shift + i (CAUTION: this one seems to be assigned already, so you might need to overwrite it. It seems to be the same one as plain i though, so you shouldn't have any disadvantages in overwriting the original one)
--   * timtam_AccessiChords process notes deferred.lua: no shortcut required
--   * timtam_AccessiChords select next chord for pitch cursor.lua: CTRL + ALT + Up
--   * timtam_AccessiChords select previous chord for pitch cursor.lua: CTRL + ALT + DOWN
--   * timtam_AccessiChords select next chord inversion.lua: CTRL + ALT + RIGHT
--   * timtam_AccessiChords select previous chord inversion.lua: CTRL + ALT + LEFT
--   * timtam_AccessiChords select next chord mode.lua: CTRL + ALT + SHIFT + Up
--   * timtam_AccessiChords select previous chord mode.lua: CTRL + ALT + SHIFT + Down
--   * timtam_AccessiChords move to next chord.lua: CTRL + SHIFT + Right (or replace OSARA's own "move to next chord" binding on the Right arrow)
--   * timtam_AccessiChords move to previous chord.lua: CTRL + SHIFT + Left (or replace OSARA's own "move to previous chord" binding on the Left arrow)

--   Note: when using MacOS, control is command and alt is option. Shift remains the same.

--   The script will be entirely keyboard-controllable afterwards.

--   ## Usage

--   All the functionalities below can and should only be executed from within the MIDI editor.

--   note: all speech announcements will only work if you've got an OSARA version installed which was released Sep 4 2020 or later. If your installed OSARA version is older than that, you won't get any speech announcements by these scripts.

--   ### Cycling through available chords

--   After you've selected a note using the pitch cursor (ALT + UP or DOWN arrow within the OSARA keymap), you can use the actions "timtam_AccessiChords select next chord for pitch cursor.lua" and "timtam_AccessiChords select previous chord for pitch cursor.lua" to cycle through all chords available for that note. When doing so, the chord will be played on the note channel selected for the virtual MIDI keyboard with the default velocity of the same. The name of the chord will also be announced by your screen reader. The scripts will also announce if the selected chord is not available for the given note.

--   The chords are presented in the following order, grouped by family. Some of the taller chords (for example the ninths, elevenths and thirteenths) will not be available near the very top of the MIDI range, since their upper notes would fall outside it; in that case the script announces that the chord does not exist.

--   * Triads: major, minor, diminished, augmented, suspended second, suspended fourth
--   * Two-note chords: power, flat fifth
--   * Added-note chords: added ninth, minor added ninth
--   * Sixths: major sixth, minor sixth
--   * Sevenths: dominant seventh, major seventh, minor seventh, minor major seventh, half diminished seventh, diminished seventh, augmented seventh, major seventh sharp fifth, dominant seventh flat fifth, dominant seventh flat ninth, dominant seventh sharp ninth
--   * Ninths: dominant ninth, major ninth, minor ninth
--   * Elevenths: minor eleventh, dominant eleventh
--   * Thirteenths: dominant thirteenth, major thirteenth

--   ### Cycling through available chord inversions

--   After selecting a note with the pitch cursor and a chord using the above actions, you can use the actions "timtam_AccessiChords select next chord inversion.lua" and "timtam_AccessiChords select previous chord inversion.lua" to cycle through the available chord inversions. Those will be announced with speech and remember as well, so that you can use the above actions to change chords while the inversion will be maintained and can be inserted as usual (see below).

--   ### Cycling through chord modes

--   You can use the actions "timtam_AccessiChords select next chord mode.lua" and "timtam_AccessiChords select previous chord mode.lua" to cycle through the available chord modes. The mode controls whether the notes of a chord are played and inserted all together or one after another. Three modes are available:

--   * block: all notes of the chord sound at the same time (the default).
--   * low to high: the notes are played in sequence starting with the lowest, so the chord is arpeggiated upwards.
--   * high to low: the notes are played in sequence starting with the highest, so the chord is arpeggiated downwards.

--   The selected mode is announced with speech and remembered, so it applies to every chord you preview and insert until you change it again. For the low to high and high to low modes, the spacing between the notes is derived from the length of the note that would be inserted (the next note length if set, otherwise the current grid size). When inserting, the notes are written into the MIDI editor staggered accordingly, giving you an actual arpeggio in the item.

--   ### Inserting a selected chord

--   When having a chord selected, you can use the action "timtam_AccessiChords insert selected chord for pitch cursor.lua" to insert this chord at the current position into the MIDI editor. The notes will have the length of the current grid size or, if the length of the next inserted note is set using the appropriate reaper-native actions, they will have the appropriate length as well. The chord will be played again and the edit cursor will automatically be moved along the track by the size of the inserted notes.
--   Note though that in contradiction to reaper-native note insertion, there currently is no speech when the cursor is moved that way. This will be considered a feature later to be implemented though.

--   ### Moving through and reporting existing chords

--   Once you have chords in your MIDI editor, you can move through them with the actions "timtam_AccessiChords move to next chord.lua" and "timtam_AccessiChords move to previous chord.lua". These build on OSARA's own robust chord navigation, but silence OSARA's report and describe the chord in AccessiChords' own words instead. Each chord is identified and announced by name, for example "E flat major", "D dominant seventh, first inversion" or "C half diminished seventh", including inversions and any added tensions.

--   Note spelling (whether an accidental is spoken as a flat or a sharp) follows the key you have set with REAPER's native snap to key in the MIDI editor. For example, in G major an F sharp is spoken as "F sharp", while in E flat major a B flat is spoken as "B flat". When no key is set, flats are used by default.

--   To set the key in an accessible way you need REAPER 7.75 or newer. The snap to key control lives in the Options menu at the top of the MIDI editor. AccessiChords reads this native setting directly, so there is no separate key to configure and it is saved with your project.

--   <!-- ROADMAP -->
--   ## Roadmap

--   See the [open issues](https://github.com/Timtam/AccessiChords/issues) for a list of proposed features (and known issues).

--   <!-- CONTRIBUTING -->
--   ## Contributing

--   Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.

--   ### Contribute by coding

--   1. Fork the Project
--   2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
--   3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
--   4. Push to the Branch (`git push origin feature/AmazingFeature`)
--   5. Open a Pull Request

--   ### Contribute by testing

--   Feel free to give these scripts a go and see if they fit your workflow.
--   Do you like those scripts, but can think of a way they might become even more useful to you? Feel free to let me know by opening an issue or contacting me via email at <software@satoprogs.de>.
--   Same goes for bugs you might have encountered or new features you'd like to see.

--   ### Contribute by paying me a coffee

--   Developing takes time and effort and since those scripts are free to use and open-source, I don't get anything out of it except appreciation. Appreciation doesn't pay monthly bills though. 
--   If you think those scripts greatly improved your life by helping you with your productivity and workflow, or you simply want to give something back, i'd greatly appreciate a small donation via PayPal to the following link: <https://paypal.me/ToniRonaldBarth>
--   Don't feel obligated though.

--   <!-- LICENSE -->
--   ## License

--   Distributed under the GNU GPL v3 License. See `LICENSE` for more information.

--   <!-- CONTACT -->
--   ## Contact

--   Toni Barth - [@GixGax95](https://twitter.com/GixGax95) - software@satoprogs.de

--   Project Link: [https://github.com/Timtam/AccessiChords](https://github.com/Timtam/AccessiChords)



--   <!-- MARKDOWN LINKS & IMAGES -->
--   <!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
--   [contributors-shield]: https://img.shields.io/github/contributors/Timtam/AccessiChords.svg?style=flat-square
--   [contributors-url]: https://github.com/Timtam/AccessiChords/graphs/contributors
--   [forks-shield]: https://img.shields.io/github/forks/Timtam/AccessiChords.svg?style=flat-square
--   [forks-url]: https://github.com/Timtam/AccessiChords/network/members
--   [stars-shield]: https://img.shields.io/github/stars/Timtam/AccessiChords.svg?style=flat-square
--   [stars-url]: https://github.com/Timtam/AccessiChords/stargazers
--   [issues-shield]: https://img.shields.io/github/issues/Timtam/AccessiChords.svg?style=flat-square
--   [issues-url]: https://github.com/Timtam/AccessiChords/issues
--   [license-shield]: https://img.shields.io/github/license/Timtam/AccessiChords.svg?style=flat-square
--   [license-url]: https://github.com/Timtam/AccessiChords/blob/master/LICENSE
--   [chordgun-url]: https://github.com/benjohnson2001/ChordGun "ChordGun scripts"

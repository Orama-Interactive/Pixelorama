"""
po2nsi.py: Create multilingual NSIS script based on gettext
PO files

Copyright (C) 2021 huskee 
(Original author: Dan Chowdhury)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""

import collections
import os
import polib
from optparse import OptionParser

parser = OptionParser()
parser.add_option("-i", "--input", dest="input",
                  help="NSIS script to be localized", metavar="script.nsi")
parser.add_option("-o", "--output", dest="output",
                  help="Localized script output location", metavar="script.nsi")
parser.add_option("-p", "--podir", dest="podir",
                  help="Directory containing PO files")
parser.add_option("-l", "--lang", dest="lang",
                  help="NSIS script default language (default is English)", default="English" )
parser.add_option("-v", "--verbose", action="store_true",
                  dest="verbose", help="Verbose output")                  

(options, args) = parser.parse_args()


# Define a dict to convert locale names to language names
localeToName = {
    "af-ZA" : "Afrikaans",
    "ar-SA" : "Arabic",
    "ca-ES" : "Catalan",
    "cs-CZ" : "Czech",
    "da-DK" : "Danish",
    "nl-NL" : "Dutch",
    "en" : "English",
    "eo-UY" : "Esperanto",
    "fi-FI" : "Finnish",
    "fr-FR" : "French",
    "de-DE" : "German",
    "el-GR" : "Greek",
    "he-IL" : "Hebrew",
    "hi-IN" : "Hindi",
    "hu-HU" : "Hungarian",
    "id-ID" : "Indonesian",
    "it-IT" : "Italian",
    "ja-JP" : "Japanese",
    "ko-KR" : "Korean",
    "lv-LV" : "Latvian",
    "no-NO" : "Norwegian",
    "pl-PL" : "Polish",
    "pt-PT" : "Portuguese",
    "pt-BR" : "PortugueseBR",
    "ro-RO" : "Romanian",
    "ru-RU" : "Russian",
    "sr-SP" : "Serbian",
    "zh-CN" : "SimpChinese",
    "es-ES" : "Spanish",
    "sv-SE" : "Swedish",
    "zh-TW" : "TradChinese",
    "tr-TR" : "Turkish",
    "uk-UA" : "Ukrainian",
    "vi-VN" : "Vietnamese",
}

localeRTL = [ "ar-SA", "he-IL" ]

def escapeNSIS(st):
    return st.replace('\\', r'$\\')\
             .replace('\t', r'$\t')\
             .replace('\r', r'\r')\
             .replace('\n', r'\n')\
             .replace('\"', r'$\"')\
             .replace('$$\\', '$\\')

translationCache = {}

# The purpose of this loop is to go to the podir scanning for PO files for each locale name
# Once we've found a PO file, we use PO lib to read every translated entry
# Using this, for each each language, we store a dict of entries - { nsilabel (comment) : translation (msgstr) }
# For untranslated entries, we use msgid instead of msgstr (i.e. default English string)
for root,dirs,files in os.walk(options.podir):
    for file in files:
        filename,ext = os.path.splitext(file)
        if ext == ".po":
            # Valid locale filename (fr.po, de.po etc)?
            if filename not in localeToName:
                print("%s: invalid filename, must be xx-YY language code" %(filename))
            else:
                if options.verbose:
                    print("Valid filename found")             
                language = localeToName[filename]
                translationCache[language] = collections.OrderedDict()         
                # Let's add a default LANGUAGE_CODE LangString to be read
                translationCache[language]["LANGUAGE_CODE"] = filename
                if options.verbose:
                    print("Language: %s (%s)" %(language, translationCache[language]["LANGUAGE_CODE"]))

                # Are we RTL? Mark that down too as a LangString
                if filename in localeRTL:
                    translationCache[language]["LANGUAGE_RTL"] = "1"
                    if options.verbose:
                        print("RTL language")
                else:
                    if options.verbose:
                        print("Non RTL language")

                po = polib.pofile(os.path.join(root,file))
                for entry in po.translated_entries():
                    # Loop through all our labels and add translation (each translation may have multiple labels)
                    for label in entry.comment.split():
                        translationCache[language][label] = escapeNSIS(entry.msgstr)
                        if options.verbose:
                            print("msgstr added, " + translationCache[language][label])
                # For untranslated strings, let's add the English entry
                for entry in po.untranslated_entries():
                    for label in entry.comment.split():
                        print("Warning: Label '%s' for language %s remains untranslated"%(label,language))
                        translationCache[language][label] = escapeNSIS(entry.msgid)
                if options.verbose:
                    print('\n')


        


# Open our source NSI, dump it to a list and close it
NSISourceFile = open(options.input,"r")
if options.verbose:
    print("Opened source file")
NSISourceLines = NSISourceFile.readlines()
if options.verbose:
    print("Read source file lines")
NSISourceFile.close()
if options.verbose:    
    print("Closed source file")
NSINewLines = []


# Here we scan for ";@INSERT_TRANSLATIONS@" in the NSIS, and add MUI_LANGUAGE macros and LangString's for translation languages
lineNo = 1
print('\n')
for line in NSISourceLines:
    x = line.find(";@INSERT_TRANSLATIONS@")
    if x != -1:
        if options.verbose:
            print("INSERT_TRANSLATIONS found")
        NSINewLines.append('\n')
        for language,translations in translationCache.items():
            count = 0
            # if the language isn't the default, we add our MUI_LANGUAGE macro
            if language.upper() != options.lang.upper():
                NSINewLines.append('  !insertmacro MUI_LANGUAGE "%s"\n'%language)
            # For every translation we grabbed from the .po, let's add our LangString
            for label,value in translations.items():
                NSINewLines.append('  LangString %s ${LANG_%s} "%s"\n' % (label,language,value))
                count += 1
            NSINewLines.append('\n')
            print ("%i translations merged for language %s" %(count,language))
    else:
        NSINewLines.append (line)
    
# Finally, let's write our new .nsi to the desired target file
NSIWorkingFile = open(options.output,"w",encoding='utf-8')
NSIWorkingFile.writelines(NSINewLines)
NSIWorkingFile.close()
    
print ("%s: NSIS script successfully localized" %options.output)

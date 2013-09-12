"""
This plug-in provides a function to reformat the current line
or selection.
It tries to do a number of things, which can be configured
separately to suit your work style.

This function is available in GPS through the action
"Format Selection", which is bound to the <tab> key by default.
"""



import GPS
from gps_utils import interactive, in_editor
import pygps
import aliases
import align
from gi.repository import Gtk

tabs_align_selection = GPS.Preference("Editor/tabs_align_selection")
tabs_align_selection.create(
    "Align selection on tab", "boolean",
    "Whether <tab> should also align arrows, use clauses and assignments (:=)"
    " when multiple lines are selected.",
    True)

@interactive(name='smart tab',
             category='Editor',
             filter="Source editor",
             key='Tab')
def smart_tab():
    """
    This action is the default binding for the tab key, and will
    apply different behaviors depending on the current context.
    """

    editor = GPS.EditorBuffer.get()

    # When expanding aliases, <tab> should move to the next field

    if aliases.is_in_alias_expansion(editor):
        aliases.toggle_next_field(editor)
        return

    # If multiple lines are selected, perform various alignments

    if tabs_align_selection:
        start = editor.selection_start()
        end = editor.selection_end()

        if abs(start.line() - end.line()) >= 1:
            align.align_colons()
            align.align_arrows()
            align.align_use_clauses()
            align.align_assignments()

    # Otherwise, reformat the current selection

    action = GPS.Action("Format selection")
    action.execute_if_possible()


def escape_filter(context):
    if in_editor(context):
        editor = GPS.EditorBuffer.get()
        return aliases.is_in_alias_expansion(editor)
    return False


@interactive(name='smart escape',
             category='Editor',
             filter=escape_filter,
             key='Escape')
def smart_escape():
    """
    This action is the default binding for the Escape key, and will
    interrupt the current alias expansion (if any).
    """
    editor = GPS.EditorBuffer.get()
    aliases.exit_alias_expand(editor)


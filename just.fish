# Module-aware fish completions for just:
#
#     just <TAB>         root recipes (machine/dotfiles offered as entries)
#     just machine<TAB>  the machine module's recipes, with doc comments
#
# Fish loads the first just.fish found on $fish_complete_path, so once this is
# linked into ~/.config/fish/completions (`just dotfiles install-completions`)
# it shadows the root-recipes-only one fish ships in its own share dir.

function __just_positional_args
    # Completed tokens of the current process plus the token being typed
    # (fish's `-c -x` vs `-t` pair), with value-taking flags skipped together
    # with the token after them, so `just -f foo machine <TAB>` still resolves
    # the machine module.
    set -l toks (commandline -c -x -p 2>/dev/null)
    set -l cur (commandline -t 2>/dev/null)
    test -n "$cur"; and set -a toks $cur
    set toks $toks[2..-1] # the `just` command itself
    set -l value_flags \
        chooser color command-color dump-format list-heading list-prefix \
        justfile set shell shell-arg working-directory command shell-command \
        completions dotenv-filename dotenv-path group timestamp-format ceiling
    set -l out
    set -l skip_next 0
    for tok in $toks
        if test $skip_next -eq 1
            set skip_next 0
            continue
        end
        if string match -q -- '--*' $tok
            set -l flag (string split -m 1 -- '=' -- $tok)[1]
            if not string match -q -- '*=*' $tok; and contains -- \
                    (string trim --chars=- -- $flag) $value_flags
                set skip_next 1
            end
            continue
        end
        if string match -q -- '-*' $tok
            if contains -- $tok -f -F -s -c -d -E
                set skip_next 1
            end
            continue
        end
        set -a out $tok
    end
    printf '%s\n' $out
end

function __just_parse_list
    # Lines of `just --list [...]` on stdin → candidates `recipe<TAB>comment`
    # (or bare `recipe` when the recipe has no comment). Justfile listings
    # indent every recipe line, so heading lines are dropped up front.
    # Optional $argv[1]: a prefix for recipe names, e.g. `machine::` to emit
    # the one-token recipe paths just also accepts.
    set -l prefix ""
    test (count $argv) -ge 1; and set prefix $argv[1]
    while read -l line
        string match -rq -- '^\s' $line; or continue
        set -l trimmed (string trim -- $line)
        set -l name (string match -rg -- '^(\S+)' $trimmed)
        test -n "$name"; or continue
        set -l desc ""
        set -l cut (string split -m 1 -- '#' $trimmed)
        if test (count $cut) -gt 1
            set desc (string trim -- $cut[2])
        end
        if test -n "$desc"
            printf '%s%s\t%s\n' $prefix $name $desc
        else
            printf '%s%s\n' $prefix $name
        end
    end
end

function __just_complete_qualified
    # The word being completed contains `::`: offer the one-token recipe
    # paths (`machine::install-docker`), which just accepts interchangeably
    # with the space-separated form. The module must be named exactly, as
    # just does; nothing is offered for an ambiguous `m::` prefix.
    set -l cur $argv[1]
    set -l module (string match -r -- '^[^:*]+' $cur)
    test -n "$module"; or return 1
    just --list $module >/dev/null 2>&1; or return 1
    just --list $module 2>/dev/null | __just_parse_list "$module::"
    return 0
end

function __just_complete_recipes
    # $at_end: cursor sits in a fresh empty token (the word before it is done)
    set -l at_end 0
    string match -rq -- '\s$' "$(commandline -c)"; and set at_end 1
    set -l pos (__just_positional_args)

    if test (count $pos) -eq 0
        # Nothing after `just` yet: the root recipes. Module names are in that
        # list too, so `--list <TAB>` completes module names as well.
        just --list 2>/dev/null | __just_parse_list
        return 0
    end

    # `just machine::ins<TAB>`: the one-token recipe path, offered only once
    # the user types `::` themselves.
    set -l cur (commandline -t 2>/dev/null)
    if string match -q -- '*::*' "$cur"
        __just_complete_qualified "$cur"
        return 0
    end

    # `just --list <module>` exits 0 for modules and errors otherwise.
    set -l first $pos[1]
    set -l modlist (just --list $first 2>/dev/null)
    if test $status -eq 0
        if test (count $pos) -eq 1
            if test $at_end -eq 1
                # `just machine <TAB>`: this module's recipes
                printf '%s\n' $modlist | __just_parse_list
                return 0
            end
            # the module word itself is still being typed: the root list has
            # it as a candidate, fish narrows it
            just --list 2>/dev/null | __just_parse_list
            return 0
        end
        if test $at_end -eq 1
            # `just machine install-docker <TAB>`: recipes here take no args
            return 0
        end
        # `just machine ins<TAB>`: filter within this module's recipes
        printf '%s\n' $modlist | __just_parse_list
        return 0
    end

    # $first is not a module. Mid-word, offer the root list so fish narrows it
    # (`just ma<TAB>` → machine). At word end after a complete recipe name
    # (`just doctor <TAB>`) offer nothing rather than the whole list again.
    if test $at_end -eq 0
        just --list 2>/dev/null | __just_parse_list
    end
    return 0
end

# never fall back to file completions
complete -c just -f
complete -c just -a '(__just_complete_recipes)'

# options
complete -c just -n __fish_use_subcommand -l chooser -d 'Override binary invoked by `--choose`'
complete -c just -n __fish_use_subcommand -l color -d 'Print colorful output' -r -f -a "auto always never"
complete -c just -n __fish_use_subcommand -l command-color -d 'Echo recipe lines in <COMMAND-COLOR>' -r -f -a "black blue cyan green purple red yellow"
complete -c just -n __fish_use_subcommand -l completions -d 'Print shell completion script for <SHELL>' -r -f -a "zsh bash fish powershell elvish"
complete -c just -n __fish_use_subcommand -l dump-format -d 'Dump justfile as <FORMAT>' -r -f -a "just json"
complete -c just -n __fish_use_subcommand -l list-heading -d 'Print <TEXT> before list'
complete -c just -n __fish_use_subcommand -l list-prefix -d 'Print <TEXT> before each list item'
complete -c just -n __fish_use_subcommand -s f -l justfile -r -d 'Use <JUSTFILE> as justfile'
complete -c just -n __fish_use_subcommand -l set -r -d 'Override <VARIABLE> with <VALUE>'
complete -c just -n __fish_use_subcommand -l shell -r -d 'Invoke <SHELL> to run recipes'
complete -c just -n __fish_use_subcommand -l shell-arg -r -d 'Invoke shell with <SHELL-ARG> as an argument'
complete -c just -n __fish_use_subcommand -s d -l working-directory -r -d 'Use <WORKING-DIRECTORY> as working directory. --justfile must also be set'
complete -c just -n __fish_use_subcommand -s c -l command -r -d 'Run an arbitrary command with the working directory, `.env`, overrides, and exports set'
complete -c just -n __fish_use_subcommand -l shell-command -r -d 'Invoke <COMMAND> with the shell used to run recipe lines and backticks'
complete -c just -n __fish_use_subcommand -l show -d 'Show information about <RECIPE>'
complete -c just -n __fish_use_subcommand -l dotenv-filename -s F -r -d 'Search for environment file named <DOTENV-FILENAME> instead of `.env`'
complete -c just -n __fish_use_subcommand -l dotenv-command -r -d 'Run <COMMAND> and load its output as an environment file'
complete -c just -n __fish_use_subcommand -l dotenv-path -s E -r -d 'Load environment file at <DOTENV-PATH> instead of searching for one'
complete -c just -n __fish_use_subcommand -l group -r -d 'Only list recipes in <GROUP>'
complete -c just -n __fish_use_subcommand -l justfile-name -r -d 'Search for justfile named <NAME>, accepts multiple `,`-separated values and may be repeated'
complete -c just -n __fish_use_subcommand -l indentation -r -d 'Indent recipes bodies with <INDENTATION>'
complete -c just -n __fish_use_subcommand -l jobs -r -d 'Run at most <N> recipes simultaneously with the [parallel] attribute'
complete -c just -n __fish_use_subcommand -l timestamp-format -d 'Timestamp format string'
complete -c just -n __fish_use_subcommand -l tempdir -r -d 'Save temporary files to <TEMPDIR>'
complete -c just -n __fish_use_subcommand -l ceiling -r -d 'Do not ascend above <CEILING> directory when searching for a justfile'
complete -c just -n __fish_use_subcommand -l alias-style -r -f -a "left right separate"
complete -c just -n __fish_use_subcommand -l evaluate-format -r -f -a "just shell"
complete -c just -n __fish_use_subcommand -s n -l dry-run -d 'Print what just would do without doing it'
complete -c just -n __fish_use_subcommand -l check -d 'Run `--fmt` in check mode; exits with 0 if justfile is formatted correctly'
complete -c just -n __fish_use_subcommand -l allow-missing -d 'Ignore missing recipe and module errors'
complete -c just -n __fish_use_subcommand -l no-aliases -d 'Don\'t show aliases in list'
complete -c just -n __fish_use_subcommand -l no-cache -d 'Bypass recipe cache'
complete -c just -n __fish_use_subcommand -l no-deps -d 'Don\'t run recipe dependencies'
complete -c just -n __fish_use_subcommand -l no-dotenv -d 'Don\'t load `.env` file'
complete -c just -n __fish_use_subcommand -l no-highlight -d 'Don\'t highlight echoed recipe lines in bold'
complete -c just -n __fish_use_subcommand -l one -d 'Forbid multiple recipes from being invoked on the command line'
complete -c just -n __fish_use_subcommand -l clear-shell-args -d 'Clear shell arguments'
complete -c just -n __fish_use_subcommand -l default-list -d 'List recipes when no arguments are provided'
complete -c just -n __fish_use_subcommand -l list-submodules -d 'List recipes in submodules'
complete -c just -n __fish_use_subcommand -l complete-aliases -d 'Auto-complete recipe aliases'
complete -c just -n __fish_use_subcommand -l explain -d 'Print recipe doc comment before running it'
complete -c just -n __fish_use_subcommand -l clean -d 'Clear recipe cache'
complete -c just -n __fish_use_subcommand -l highlight -d 'Highlight echoed recipe lines in bold'
complete -c just -n __fish_use_subcommand -l yes -d 'Automatically confirm all recipes.'
complete -c just -n __fish_use_subcommand -s q -l quiet -d 'Suppress all output'
complete -c just -n __fish_use_subcommand -s u -l unsorted -d 'Return list and summary entries in source order'
complete -c just -n __fish_use_subcommand -l unstable -d 'Enable unstable features'
complete -c just -n __fish_use_subcommand -s v -l verbose -d 'Use verbose output'
complete -c just -n __fish_use_subcommand -l changelog -d 'Print changelog'
complete -c just -n __fish_use_subcommand -l choose -d 'Select one or more recipes to run using a binary chooser. If `--chooser` is not passed the chooser defaults to the value of $JUST_CHOOSER, falling back to `fzf`'
complete -c just -n __fish_use_subcommand -l dump -d 'Print justfile'
complete -c just -n __fish_use_subcommand -s e -l edit -d 'Edit justfile with editor given by $VISUAL or $EDITOR, falling back to `vim`'
complete -c just -n __fish_use_subcommand -l evaluate -d 'Evaluate and print all variables. If a variable name is given as an argument, only print that variable\'s value.'
complete -c just -n __fish_use_subcommand -l fmt -d 'Format and overwrite justfile'
complete -c just -n __fish_use_subcommand -l init -d 'Initialize new justfile in project root'
complete -c just -n __fish_use_subcommand -s l -l list -d 'List available recipes and their arguments'
complete -c just -n __fish_use_subcommand -l man -d 'Print man page'
complete -c just -n __fish_use_subcommand -l summary -d 'List names of available recipes'
complete -c just -n __fish_use_subcommand -l usage -d 'Print usage information for recipe at <PATH> or all recipes in module at <PATH>, defaulting to all recipes in the root justfile'
complete -c just -n __fish_use_subcommand -l variables -d 'List names of variables'
complete -c just -n __fish_use_subcommand -s h -l help -d 'Print help information'
complete -c just -n __fish_use_subcommand -s V -l version -d 'Print version information'
complete -c just -n __fish_use_subcommand -s g -l global-justfile -d 'Use global justfile'
complete -c just -n __fish_use_subcommand -l time -d 'Print recipe execution time'

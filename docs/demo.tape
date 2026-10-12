# Demo GIF for the README: tutor mode on level medium, a fix request, then one /code-tutor:hint.
# It records a real Claude Code session with the plugin installed from the marketplace.
#
# Recreate docs/demo.gif (needs vhs, ttyd and ffmpeg):
#
#   mkdir -p ~/code-tutor-demo/acme-shop && cd ~/code-tutor-demo/acme-shop
#   bash <repo>/evals/off-mode-edits-normally/scaffold.sh
#   cd <repo> && vhs docs/demo.tape
#   ffmpeg -i demo-raw.mp4 -vf "mpdecimate=hi=64*12:lo=64*5:frac=0.33:max=20,setpts=N/10/TB,fps=10,\
#     tpad=stop_mode=clone:stop_duration=5,scale=1000:-1:flags=lanczos,split[a][b];\
#     [a]palettegen=max_colors=96:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
#     docs/demo.gif
#
# mpdecimate drops frames in which nothing changes, so waiting for the model is cut
# from the GIF while every answer stays complete.

Output "demo-raw.mp4"

Require claude
Set Shell "bash"
Set FontSize 15
Set Width 1280
Set Height 820
Set Padding 16
Set Theme "Catppuccin Mocha"
Set TypingSpeed 35ms
Set CursorBlink false
Set WindowBar Colorful

Hide
# English answers and an empty status line, so no personal usage data ends up in the GIF.
# When recording from inside a Claude Code session, also unset its CLAUDE* variables (env -u).
Type `cd ~/code-tutor-demo/acme-shop && clear && claude --settings '{"language":"English","statusLine":{"type":"command","command":"true"}}'`
Enter
Sleep 5s
# folder trust dialog for the new project: "No, exit" is preselected
Down
Sleep 300ms
Enter
Sleep 6s
Show

Sleep 1s
Type "/code-tutor:tutor medium"
Sleep 600ms
Enter
Sleep 9s

Type "The cart total from src/Service/PriceCalculator.php is too low when the cart has more than one item. Please fix it."
Sleep 600ms
Enter
Sleep 28s

Type "/code-tutor:hint"
Sleep 600ms
Enter
Sleep 26s

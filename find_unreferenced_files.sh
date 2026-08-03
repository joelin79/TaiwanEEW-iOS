!/bin/zsh
PROJECT=TaiwanEEW  # <-- Replace with your actual project name (without .xcodeproj)
for file in $PROJECT*/**/*.swift
do
    grep -q "$(basename $file)" ./$PROJECT.xcodeproj/project.pbxproj || echo "$file"
done


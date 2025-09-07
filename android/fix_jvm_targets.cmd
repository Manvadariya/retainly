@echo off  
rem Fix JVM target issues in Gradle  
set TARGET_KOTLIN_JVM=11  
echo Cleaning project...  
gradlew.bat clean  
echo Applying JVM target fixes...  
gradlew.bat assembleDebug --info 
